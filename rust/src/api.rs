use flutter_rust_bridge::frb;
use lazy_static::lazy_static;
use std::cell::RefCell;
use std::sync::{Arc, Mutex};
use zecwalletlitelib::{commands, lightclient::LightClient, MainNetwork};
use zecwalletlitelib::lightclient::lightclient_config::LightClientConfig;

// Global LightClient instance (same as BitcoinZ Blue)
lazy_static! {
    static ref LIGHTCLIENT: Mutex<RefCell<Option<Arc<LightClient<MainNetwork>>>>> =
        Mutex::new(RefCell::new(None));
}

/// Check if a wallet exists
pub fn wallet_exists(_chain_name: String) -> bool {
    let config = LightClientConfig::<MainNetwork>::create_unconnected(MainNetwork, None);
    config.wallet_exists()
}

/// Initialize a new wallet and return the seed phrase
pub fn initialize_new(server_uri: String) -> String {
    let server = LightClientConfig::<MainNetwork>::get_server_or_default(Some(server_uri));
    
    let (config, latest_block_height) = match LightClientConfig::create(MainNetwork, server, None) {
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
    LightClient::start_mempool_monitor(lc.clone());

    // Store the client globally
    LIGHTCLIENT.lock().unwrap().replace(Some(lc));

    seed
}

/// Initialize from an existing wallet
pub fn initialize_existing(server_uri: String) -> String {
    let server = LightClientConfig::<MainNetwork>::get_server_or_default(Some(server_uri));
    
    let (config, _latest_block_height) = match LightClientConfig::create(MainNetwork, server, None) {
        Ok((c, h)) => (c, h),
        Err(e) => return format!("Error: {}", e),
    };

    // Read existing wallet from disk instead of creating new
    let lightclient = match LightClient::read_from_disk(&config) {
        Ok(l) => l,
        Err(e) => return format!("Error: {}", e),
    };

    // Initialize logging
    let _ = lightclient.init_logging();

    // Start mempool monitor (CRITICAL for unconfirmed transactions!)
    let lc = Arc::new(lightclient);
    LightClient::start_mempool_monitor(lc.clone());

    // Store the client globally
    LIGHTCLIENT.lock().unwrap().replace(Some(lc));

    "OK".to_string()
}

/// Initialize from seed phrase
pub fn initialize_from_phrase(
    server_uri: String, 
    seed_phrase: String, 
    birthday: u64, 
    overwrite: bool
) -> String {
    let server = LightClientConfig::<MainNetwork>::get_server_or_default(Some(server_uri));
    
    let (config, _latest_block_height) = match LightClientConfig::create(MainNetwork, server, None) {
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
    LightClient::start_mempool_monitor(lc.clone());

    // Store the client globally
    LIGHTCLIENT.lock().unwrap().replace(Some(lc));

    "OK".to_string()
}

/// Execute a command (main wallet interface)
pub fn execute(command: String, args: String) -> String {
    let lightclient = LIGHTCLIENT.lock().unwrap().borrow().clone();
    
    let lightclient = match lightclient {
        Some(l) => l,
        None => return r#"{"error": "Wallet not initialized"}"#.to_string(),
    };

    // Log unconfirmed transaction checks
    if command == "list" {
        println!("🔍 Fetching transaction list (checking for unconfirmed)...");
    }

    let args_vec: Vec<&str> = if args.is_empty() {
        vec![]
    } else {
        args.split_whitespace().collect()
    };
    
    commands::do_user_command(&command, &args_vec, lightclient.as_ref())
}

/// Deinitialize the wallet
pub fn deinitialize() -> String {
    LIGHTCLIENT.lock().unwrap().replace(None);
    "OK".to_string()
}

/// Get sync status
#[frb(sync)]
pub fn get_sync_status() -> String {
    execute("syncstatus".to_string(), "".to_string())
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
pub async fn send_transaction(address: String, amount: u64, memo: Option<String>) -> String {
    let args = if let Some(m) = memo {
        format!("{} {} \"{}\"", address, amount, m)
    } else {
        format!("{} {}", address, amount)
    };
    
    execute("send".to_string(), args)
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