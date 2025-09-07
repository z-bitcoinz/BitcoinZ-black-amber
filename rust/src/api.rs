use flutter_rust_bridge::frb;
use lazy_static::lazy_static;
use std::cell::RefCell;
use std::sync::{Arc, Mutex};
use std::path::Path;
use tokio::runtime::Runtime;
use tokio::sync::broadcast;
use tokio::time::{sleep, Duration};
use futures::Stream;
use serde_json;
use chrono;
use zecwalletlitelib::{commands, lightclient::LightClient, MainNetwork};
use zecwalletlitelib::lightclient::lightclient_config::LightClientConfig;
use zecwalletlitelib::grpc_connector::GrpcConnector;

// Global reference to progress sender for use from zecwalletlitelib
static mut GLOBAL_PROGRESS_SENDER: Option<broadcast::Sender<String>> = None;

// Global LightClient instance (same as BitcoinZ Blue)
lazy_static! {
    static ref LIGHTCLIENT: Mutex<RefCell<Option<Arc<LightClient<MainNetwork>>>>> =
        Mutex::new(RefCell::new(None));
    static ref PROGRESS_SENDER: Mutex<Option<broadcast::Sender<String>>> =
        Mutex::new(None);
}

/// Check if a wallet exists
pub fn wallet_exists(wallet_dir: Option<String>) -> bool {
    let config = if let Some(ref dir) = wallet_dir {
        LightClientConfig::<MainNetwork>::create_unconnected(MainNetwork, Some(dir.clone()))
    } else {
        LightClientConfig::<MainNetwork>::create_unconnected(MainNetwork, None)
    };
    
    let exists = config.wallet_exists();
    let wallet_path = config.get_wallet_path();
    
    // Only log in debug builds
    #[cfg(debug_assertions)]
    {
        if exists {
            println!("Wallet exists at: {:?}", wallet_path);
        } else {
            println!("No wallet found at: {:?}", wallet_path);
        }
    }
    
    exists
}

/// Initialize a new wallet and return the seed phrase
pub fn initialize_new(server_uri: String, wallet_dir: Option<String>) -> String {
    let server = LightClientConfig::<MainNetwork>::get_server_or_default(Some(server_uri));
    
    let (config, latest_block_height) = match LightClientConfig::create(MainNetwork, server, wallet_dir) {
        Ok((c, h)) => (c, h),
        Err(e) => return format!("Error: {}", e),
    };

    let lightclient = match LightClient::new(&config, latest_block_height.saturating_sub(100)) {
        Ok(l) => l,
        Err(e) => return format!("Error: {}", e),
    };

    // Initialize logging
    let _ = lightclient.init_logging();

    // Get the seed phrase
    let seed = match lightclient.do_seed_phrase_sync() {
        Ok(s) => s.to_string(),
        Err(e) => return format!("Error: {}", e),
    };

    // Start mempool monitor (CRITICAL for unconfirmed transactions!)
    let lc = Arc::new(lightclient);
    #[cfg(debug_assertions)]
    println!("Starting mempool monitor for unconfirmed transaction detection...");
    LightClient::start_mempool_monitor(lc.clone());
    #[cfg(debug_assertions)]
    println!("Mempool monitor started");

    // Store the client globally
    LIGHTCLIENT.lock().unwrap().replace(Some(lc));

    seed
}

/// Initialize a new wallet and return both seed phrase and birthday
pub fn initialize_new_with_info(server_uri: String, wallet_dir: Option<String>) -> String {
    let server = LightClientConfig::<MainNetwork>::get_server_or_default(Some(server_uri));
    
    let (config, latest_block_height) = match LightClientConfig::create(MainNetwork, server, wallet_dir) {
        Ok((c, h)) => (c, h),
        Err(e) => return format!("Error: {}", e),
    };

    // Calculate birthday (current height - 100 blocks for safety)
    let birthday = latest_block_height.saturating_sub(100);

    let lightclient = match LightClient::new(&config, birthday) {
        Ok(l) => l,
        Err(e) => return format!("Error: {}", e),
    };

    // Initialize logging
    let _ = lightclient.init_logging();

    // Get the seed phrase
    let seed_response = match lightclient.do_seed_phrase_sync() {
        Ok(s) => s.to_string(),
        Err(e) => return format!("Error: {}", e),
    };
    
    // Extract the actual seed phrase from the JSON response
    // The response is like {"seed":"words here..."} but might have escaped quotes
    let seed = if seed_response.contains("\"seed\":") {
        // Find the start of the seed value
        if let Some(start_idx) = seed_response.find("\"seed\":\"") {
            let start = start_idx + 8; // Length of "seed":"
            // Find the closing quote (handle escaped quotes)
            let remaining = &seed_response[start..];
            let mut end = 0;
            let chars: Vec<char> = remaining.chars().collect();
            let mut escaped = false;
            for (i, &ch) in chars.iter().enumerate() {
                if escaped {
                    escaped = false;
                    continue;
                }
                if ch == '\\' {
                    escaped = true;
                    continue;
                }
                if ch == '"' {
                    end = i;
                    break;
                }
            }
            if end > 0 {
                remaining[..end].to_string()
            } else {
                seed_response
            }
        } else {
            seed_response
        }
    } else {
        seed_response
    };

    // Start mempool monitor (CRITICAL for unconfirmed transactions!)
    let lc = Arc::new(lightclient);
    #[cfg(debug_assertions)]
    println!("Starting mempool monitor for unconfirmed transaction detection...");
    LightClient::start_mempool_monitor(lc.clone());
    #[cfg(debug_assertions)]
    println!("Mempool monitor started");

    // Store the client globally
    LIGHTCLIENT.lock().unwrap().replace(Some(lc));

    // Return JSON with both seed and birthday
    format!(r#"{{"seed": "{}", "birthday": {}, "latest_block": {}}}"#, 
            seed, birthday, latest_block_height)
}

/// Initialize from an existing wallet
pub fn initialize_existing(server_uri: String, wallet_dir: Option<String>) -> String {
    initialize_existing_with_birthday(server_uri, wallet_dir, 0)
}

/// Initialize from an existing wallet with birthday height
pub fn initialize_existing_with_birthday(server_uri: String, wallet_dir: Option<String>, birthday: u64) -> String {
    // Log the wallet directory being used
    if let Some(ref dir) = wallet_dir {
        println!("📁 Attempting to load wallet from directory: {}", dir);
    } else {
        println!("📁 Attempting to load wallet from default directory");
    }
    
    let server = LightClientConfig::<MainNetwork>::get_server_or_default(Some(server_uri));
    
    let (config, _latest_block_height) = match LightClientConfig::create(MainNetwork, server, wallet_dir.clone()) {
        Ok((c, h)) => (c, h),
        Err(e) => return format!("Error: {}", e),
    };

    // Check if wallet file exists
    let wallet_path = config.get_wallet_path();
    // Wallet path lookup completed
    
    if !wallet_path.exists() {
        println!("❌ Wallet file does not exist at: {:?}", wallet_path);
        return format!("Error: Wallet file not found at: {:?}", wallet_path);
    }
    
    println!("✅ Wallet file exists, attempting to read...");

    // Read existing wallet from disk instead of creating new
    let mut lightclient = match LightClient::read_from_disk(&config) {
        Ok(l) => {
            println!("✅ Successfully read wallet from disk");
            l
        },
        Err(e) => {
            // If reading from disk fails, it might be because the wallet doesn't exist yet
            // In that case, we should return an error that the Flutter side can handle
            println!("⚠️ Could not read wallet from disk: {}", e);
            return format!("Error: Could not read wallet file: {}", e);
        }
    };

    // Set the birthday height if provided (non-zero)
    if birthday > 0 {
        println!("📅 Using birthday height for existing wallet: {}", birthday);
        // This will help the wallet skip scanning blocks before the birthday
        // Note: LightClient may not have a direct method to set birthday after loading,
        // but it should use the stored birthday from the wallet file
    }

    // Initialize logging
    let _ = lightclient.init_logging();

    // Start mempool monitor (CRITICAL for unconfirmed transactions!)
    let lc = Arc::new(lightclient);
    #[cfg(debug_assertions)]
    println!("Starting mempool monitor for unconfirmed transaction detection...");
    LightClient::start_mempool_monitor(lc.clone());
    #[cfg(debug_assertions)]
    println!("Mempool monitor started");

    // Store the client globally
    LIGHTCLIENT.lock().unwrap().replace(Some(lc));

    format!(r#"{{"status": "OK", "birthday": {}}}"#, birthday)
}

/// Initialize from seed phrase (simplified version without wallet_dir to avoid serialization issues)
pub fn initialize_from_phrase_simple(
    server_uri: String,
    seed_phrase: String,
) -> String {
    // Use default values to avoid serialization issues
    let birthday: u64 = 0;
    let overwrite = true;
    let wallet_dir: Option<String> = None;
    
    initialize_from_phrase(server_uri, seed_phrase, birthday, overwrite, wallet_dir)
}

/// Initialize from seed phrase
pub fn initialize_from_phrase(
    server_uri: String, 
    seed_phrase: String, 
    birthday: u64, 
    overwrite: bool,
    wallet_dir: Option<String>
) -> String {
    let server = LightClientConfig::<MainNetwork>::get_server_or_default(Some(server_uri));
    
    let (config, _latest_block_height) = match LightClientConfig::create(MainNetwork, server, wallet_dir) {
        Ok((c, h)) => (c, h),
        Err(e) => return format!("Error: {}", e),
    };

    // If overwrite is specified, delete existing wallet
    if overwrite && config.wallet_exists() {
        let _wallet_path = config.get_wallet_path();
        // Delete wallet file if needed
    }

    let lightclient = match LightClient::new_from_phrase(
        seed_phrase, 
        &config, 
        birthday, 
        false
    ) {
        Ok(l) => l,
        Err(e) => return format!("Error: {}", e),
    };

    // Initialize logging
    let _ = lightclient.init_logging();

    // Start mempool monitor (CRITICAL for unconfirmed transactions!)
    let lc = Arc::new(lightclient);
    #[cfg(debug_assertions)]
    println!("Starting mempool monitor for unconfirmed transaction detection...");
    LightClient::start_mempool_monitor(lc.clone());
    #[cfg(debug_assertions)]
    println!("Mempool monitor started");

    // Store the client globally
    LIGHTCLIENT.lock().unwrap().replace(Some(lc));

    "OK".to_string()
}

/// Execute a command (main wallet interface)
pub fn execute(command: String, args: String) -> String {
    // Debug logging only in debug builds to reduce log spam
    #[cfg(debug_assertions)]
    println!("🔧 API.RS EXECUTE: command='{}'", command);
    
    let lightclient = LIGHTCLIENT.lock().unwrap().borrow().clone();
    
    let lightclient = match lightclient {
        Some(l) => l,
        None => return r#"{"error": "Wallet not initialized"}"#.to_string(),
    };

    let args_vec: Vec<&str> = if args.is_empty() {
        vec![]
    } else if command == "send" && args.starts_with('[') {
        // For send command with JSON format, pass as single argument
        vec![&args]
    } else {
        // For other commands, use normal whitespace splitting
        args.split_whitespace().collect()
    };
    
    let result = commands::do_user_command(&command, &args_vec, lightclient.as_ref());
    result
}

/// Deinitialize the wallet
pub fn deinitialize() -> String {
    LIGHTCLIENT.lock().unwrap().replace(None);
    "OK".to_string()
}

/// Get sync status
#[frb(sync)]
pub fn get_sync_status() -> String {
    let result = execute("syncstatus".to_string(), "".to_string());
    println!("📊 Sync status result: {}", result);
    result
}

/// Sync the wallet
pub async fn sync() -> String {
    execute("sync".to_string(), "".to_string())
}

/// Get balance
#[frb(sync)]
pub fn get_balance() -> String {
    execute("balance".to_string(), "".to_string())
}

/// Get transaction list
#[frb(sync)]
pub fn get_transactions() -> String {
    execute("list".to_string(), "".to_string())
}



/// Send transaction
pub async fn send_transaction(address: String, amount: i64, memo: Option<String>) -> String {
    println!("PROGRESS STREAM: Send transaction initiated");

    // Emit initial progress
    let _ = send_progress_update("{\"status\": \"sending\", \"progress\": 0, \"total\": 100, \"error\": null, \"txid\": null}".to_string());

    // Get lightclient instance
    let lightclient = LIGHTCLIENT.lock().unwrap().borrow().clone();
    let lightclient = match lightclient {
        Some(l) => l,
        None => {
            let _ = send_progress_update("{\"status\": \"error\", \"progress\": 0, \"total\": 100, \"error\": \"Wallet not initialized\", \"txid\": null}".to_string());
            return r#"{"error": "Wallet not initialized"}"#.to_string();
        }
    };

    // Convert amount to u64 (do_send expects u64)
    let amount_u64 = if amount < 0 {
        let _ = send_progress_update("{\"status\": \"error\", \"progress\": 0, \"total\": 100, \"error\": \"Invalid amount\", \"txid\": null}".to_string());
        return r#"{"error": "Invalid amount: cannot be negative"}"#.to_string();
    } else {
        amount as u64
    };

    // Prepare the address, amount, memo tuple for do_send
    let addrs = vec![(&*address, amount_u64, memo)];

    println!("PROGRESS STREAM: Starting transaction preparation");
    let _ = send_progress_update("{\"status\": \"sending\", \"progress\": 0, \"total\": 100, \"error\": null, \"txid\": null}".to_string());

    // Small delay to show preparation message
    tokio::time::sleep(tokio::time::Duration::from_millis(200)).await;

    println!("PROGRESS STREAM: Starting transaction build");
    let _ = send_progress_update("{\"status\": \"sending\", \"progress\": 10, \"total\": 100, \"error\": null, \"txid\": null}".to_string());

    // Call lightclient.do_send() directly (already in async context)
    match lightclient.do_send(addrs).await {
        Ok(txid) => {
            println!("PROGRESS STREAM: Transaction sent successfully");
            let _ = send_progress_update("{\"status\": \"sending\", \"progress\": 90, \"total\": 100, \"error\": null, \"txid\": null}".to_string());

            // Small delay to show broadcasting message
            tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;

            let _ = send_progress_update(format!("{{\"status\": \"completed\", \"progress\": 100, \"total\": 100, \"error\": null, \"txid\": \"{}\"}}", txid));

            // Transaction sent successfully
            format!(r#"{{"txid": "{}"}}"#, txid)
        }
        Err(e) => {
            println!("PROGRESS STREAM: Transaction send failed: {}", e);
            let _ = send_progress_update(format!("{{\"status\": \"error\", \"progress\": 0, \"total\": 100, \"error\": \"{}\", \"txid\": null}}", e.replace("\"", "\\\"")));

            // Transaction send failed
            // Escape quotes in error message to prevent JSON issues
            let escaped_error = e.replace("\"", "\\\"");
            format!(r#"{{"error": "{}"}}"#, escaped_error)
        }
    }
}

/// Get addresses
#[frb(sync)]
pub fn get_addresses() -> String {
    execute("addresses".to_string(), "".to_string())
}

/// Generate new address
#[frb(sync)]
pub fn new_address(address_type: String) -> String {
    execute("new".to_string(), address_type)
}

/// Get wallet height
#[frb(sync)]
pub fn get_height() -> u32 {
    let result = execute("height".to_string(), "".to_string());
    
    // Parse the JSON response to get height
    if let Ok(json) = serde_json::from_str::<serde_json::Value>(&result) {
        if let Some(height) = json["height"].as_u64() {
            return height as u32;
        }
    }
    
    0
}

/// Get info
#[frb(sync)]
pub fn get_info() -> String {
    execute("info".to_string(), "".to_string())
}

/// Get server information using gRPC GetLightdInfo call
/// Returns JSON string with complete server details or error information
pub async fn get_server_info(server_uri: String) -> String {
    println!("🌐 Testing server connection: {}", server_uri);
    
    // Parse the server URI
    let uri = match server_uri.parse::<http::Uri>() {
        Ok(u) => u,
        Err(e) => {
            return serde_json::json!({
                "error": format!("Invalid server URI: {}", e),
                "details": "Please check the server URL format"
            }).to_string();
        }
    };
    
    // Use GrpcConnector to get server info
    match GrpcConnector::get_info(uri).await {
        Ok(lightd_info) => {
            println!("✅ Server connection successful");
            println!("   Version: {}", lightd_info.version);
            println!("   Vendor: {}", lightd_info.vendor);
            println!("   Chain: {}", lightd_info.chain_name);
            println!("   Block Height: {}", lightd_info.block_height);
            
            // Convert LightdInfo to JSON
            serde_json::json!({
                "success": true,
                "version": lightd_info.version,
                "vendor": lightd_info.vendor,
                "taddr_support": lightd_info.taddr_support,
                "chain_name": lightd_info.chain_name,
                "sapling_activation_height": lightd_info.sapling_activation_height,
                "consensus_branch_id": lightd_info.consensus_branch_id,
                "block_height": lightd_info.block_height,
                "git_commit": lightd_info.git_commit,
                "branch": lightd_info.branch,
                "build_date": lightd_info.build_date,
                "build_user": lightd_info.build_user,
                "estimated_height": lightd_info.estimated_height,
                "zcashd_build": lightd_info.zcashd_build,
                "zcashd_subversion": lightd_info.zcashd_subversion,
                "timestamp": chrono::Utc::now().timestamp()
            }).to_string()
        },
        Err(e) => {
            println!("❌ Server connection failed: {}", e);
            serde_json::json!({
                "error": format!("Failed to connect to server: {}", e),
                "details": "Please check server URL and network connectivity",
                "timestamp": chrono::Utc::now().timestamp()
            }).to_string()
        }
    }
}

/// Get send progress (synchronous version for polling)
#[frb(sync)]
pub fn get_send_progress() -> String {
    execute("sendprogress".to_string(), "".to_string())
}

/// Initialize progress stream
pub fn init_progress_stream() -> String {
    let (tx, _rx) = broadcast::channel(100);
    
    // Store the sender globally
    if let Ok(mut sender) = PROGRESS_SENDER.lock() {
        *sender = Some(tx);
        println!("PROGRESS STREAM: Initialized broadcast channel");
        "OK".to_string()
    } else {
        "Error: Failed to initialize progress stream".to_string()
    }
}

/// Get next progress update (for stream-like polling)
pub async fn get_next_progress_update() -> String {
    println!("PROGRESS STREAM: Client requesting next progress update");

    // Get a receiver from the global sender
    let receiver = if let Ok(sender_guard) = PROGRESS_SENDER.lock() {
        if let Some(sender) = sender_guard.as_ref() {
            println!("PROGRESS STREAM: Creating receiver from existing sender");
            Some(sender.subscribe())
        } else {
            println!("PROGRESS STREAM: No sender available, initializing");
            None
        }
    } else {
        println!("PROGRESS STREAM: Failed to lock sender");
        None
    };

    // If no sender exists, create one
    let mut rx = if let Some(recv) = receiver {
        recv
    } else {
        // Initialize if not already done
        let (tx, rx) = broadcast::channel(100);
        if let Ok(mut sender) = PROGRESS_SENDER.lock() {
            *sender = Some(tx);
        }
        rx
    };

    // Wait for next progress update
    match rx.recv().await {
        Ok(progress_data) => {
            println!("PROGRESS STREAM: Received progress: {}", progress_data);
            progress_data
        }
        Err(e) => {
            println!("PROGRESS STREAM: Receive failed: {}", e);
            format!("{{\"error\": \"{}\"}}", e)
        }
    }
}

/// Send progress update (called from transaction building)
pub fn send_progress_update(progress_data: String) -> String {
    println!("PROGRESS STREAM: Sending progress update: {}", progress_data);
    
    if let Ok(sender_guard) = PROGRESS_SENDER.lock() {
        if let Some(sender) = sender_guard.as_ref() {
            match sender.send(progress_data.clone()) {
                Ok(subscriber_count) => {
                    println!("PROGRESS STREAM: Sent to {} subscribers", subscriber_count);
                    "OK".to_string()
                }
                Err(e) => {
                    println!("PROGRESS STREAM: Send failed: {}", e);
                    format!("Error: {}", e)
                }
            }
        } else {
            println!("PROGRESS STREAM: No sender available");
            "Error: No sender initialized".to_string()
        }
    } else {
        println!("PROGRESS STREAM: Failed to lock sender");
        "Error: Failed to lock sender".to_string()
    }
}

/// Export C-compatible function for zecwalletlitelib to call
/// This allows the fallback progress system to emit stream events
#[no_mangle]
pub extern "C" fn emit_progress_update(progress: u32, total: u32) {
    // Clamp progress to not exceed total to prevent "3 of 2" issues
    let clamped_progress = progress.min(total);

    // Convert to percentage for consistent display
    // Map note processing (which happens 50-90% of transaction) to that range
    let progress_percent = if total > 0 {
        let base_percent = (clamped_progress as f64 / total as f64) * 100.0;

        // Map 0-100% note progress to 50-90% transaction progress
        // This gives note processing 40% of the total progress bar
        let mapped_percent = 50.0 + (base_percent * 0.4);
        mapped_percent.min(90.0) as u32
    } else {
        50 // Start of note processing
    };

    let progress_json = format!(
        r#"{{"status": "sending", "progress": {}, "total": 100, "error": null, "txid": null}}"#,
        progress_percent
    );
    println!("PROGRESS STREAM: C bridge emitting: {}% (from note {}/{})", progress_percent, clamped_progress, total);
    let _ = send_progress_update(progress_json);
}

/// Initialization function to set up global progress sender for C bridge
#[no_mangle]
pub extern "C" fn init_progress_bridge() {
    unsafe {
        if let Ok(sender_guard) = PROGRESS_SENDER.lock() {
            if let Some(sender) = sender_guard.as_ref() {
                // Create a new sender for the global static
                GLOBAL_PROGRESS_SENDER = Some(sender.clone());
                println!("PROGRESS STREAM: Global progress sender initialized");
            }
        }
    }
}