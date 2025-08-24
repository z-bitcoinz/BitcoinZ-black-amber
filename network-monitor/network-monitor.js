const puppeteer = require('puppeteer');
const fs = require('fs-extra');
const chalk = require('chalk');
const path = require('path');

// Configuration
const CONFIG = {
  loginUrl: 'https://streaming-elbrus.su/?do=dillers&d=1',
  username: 'Simbav911',
  password: '8g9a505hfh8',
  targetUserId: '46259',
  targetUsername: 'prov_lilija1000_31194',
  outputDir: './captured-requests',
  headless: false,
  devtools: true
};

// Storage for captured requests
const capturedRequests = [];
let requestCounter = 0;
let lastClickedElement = null;
let currentActionGroup = null;

// Ensure output directory exists
fs.ensureDirSync(CONFIG.outputDir);

// Main monitoring function
async function startMonitoring() {
  console.log(chalk.blue.bold('\n🚀 Starting Network Monitor for IPTV Provider API\n'));
  console.log(chalk.yellow('Configuration:'));
  console.log(chalk.gray(`  URL: ${CONFIG.loginUrl}`));
  console.log(chalk.gray(`  Username: ${CONFIG.username}`));
  console.log(chalk.gray(`  Target User: ${CONFIG.targetUsername} (ID: ${CONFIG.targetUserId})\n`));

  // Launch browser
  const browser = await puppeteer.launch({
    headless: CONFIG.headless,
    devtools: CONFIG.devtools,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--window-size=1920,1080'
    ]
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080 });

  // Enable request interception
  await page.setRequestInterception(true);
  
  // Track all clicks on the page
  await page.evaluateOnNewDocument(() => {
    window.addEventListener('click', (e) => {
      const target = e.target;
      const clickInfo = {
        tagName: target.tagName,
        text: target.innerText?.substring(0, 50),
        href: target.href,
        onclick: target.getAttribute('onclick'),
        className: target.className,
        id: target.id,
        timestamp: new Date().toISOString()
      };
      window.__lastClick = clickInfo;
      console.log('CLICKED:', JSON.stringify(clickInfo));
    }, true);
  });
  
  // Listen for console messages from the page (to get click info)
  page.on('console', async (msg) => {
    const text = msg.text();
    if (text.startsWith('CLICKED:')) {
      try {
        const clickData = JSON.parse(text.replace('CLICKED:', ''));
        lastClickedElement = clickData;
        currentActionGroup = `Click_${requestCounter + 1}_${clickData.text?.replace(/\s+/g, '_') || clickData.tagName}`;
        console.log(chalk.magenta.bold(`\n👆 USER CLICKED: ${clickData.text || clickData.tagName}`));
        if (clickData.onclick) {
          console.log(chalk.yellow(`   OnClick: ${clickData.onclick}`));
        }
        if (clickData.href) {
          console.log(chalk.yellow(`   Href: ${clickData.href}`));
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }
  });

  // Monitor all requests
  page.on('request', async (request) => {
    const url = request.url();
    const method = request.method();
    const headers = request.headers();
    const postData = request.postData();

    // Filter for interesting requests (AJAX, API calls)
    // ENHANCED: Focus on billing-related requests
    const isBillingRequest = url.includes('Billing') || url.includes('Tariff');
    const isAjaxRequest = url.includes('/ajax/') || url.includes('controller.php');
    const isApiRequest = url.includes('api/');
    const isFormPost = method === 'POST' && !url.includes('.css') && !url.includes('.js') && !url.includes('.png') && !url.includes('.jpg');
    
    if (isBillingRequest || isAjaxRequest || isApiRequest || isFormPost) {
      
      requestCounter++;
      const timestamp = new Date().toISOString();
      
      const requestInfo = {
        id: requestCounter,
        timestamp,
        url,
        method,
        headers,
        postData,
        queryParams: new URL(url).searchParams.toString(),
        triggeredBy: lastClickedElement,
        actionGroup: currentActionGroup,
        isBillingRequest,
        module: url.match(/mod=([^&]+)/)?.[1],
        plugin: url.match(/plugin=([^&]+)/)?.[1]
      };

      // Log to console with enhanced color coding
      if (isBillingRequest) {
        console.log(chalk.red.bold(`\n⚡ [${requestCounter}] BILLING REQUEST - ${method}:`));
      } else {
        console.log(chalk.green.bold(`\n📡 [${requestCounter}] ${method} Request Captured:`));
      }
      
      console.log(chalk.cyan('URL:'), url);
      
      if (requestInfo.module) {
        console.log(chalk.magenta('Module:'), requestInfo.module);
        console.log(chalk.magenta('Plugin:'), requestInfo.plugin || 'N/A');
        
        // Highlight if it's the NEW endpoint we're looking for
        if (requestInfo.module === 'BillingTariff') {
          console.log(chalk.bgRed.white.bold(' 🎯 NEW BILLING TARIFF ENDPOINT FOUND! '));
        }
      }
      
      if (lastClickedElement) {
        console.log(chalk.blue('Triggered by:'), lastClickedElement.text || lastClickedElement.onclick || 'Unknown');
      }
      
      if (postData) {
        console.log(chalk.yellow('POST Data:'), postData);
        
        // Parse form data if possible
        try {
          const params = new URLSearchParams(postData);
          console.log(chalk.yellow('Parsed Parameters:'));
          for (const [key, value] of params) {
            console.log(chalk.gray(`  ${key}: ${value}`));
          }
        } catch (e) {
          // Not form data, might be JSON
          try {
            const jsonData = JSON.parse(postData);
            console.log(chalk.yellow('JSON Data:'), JSON.stringify(jsonData, null, 2));
          } catch (e2) {
            // Raw data
          }
        }
      }

      // Store request for later
      capturedRequests.push(requestInfo);
      
      // Save immediately to file
      await saveRequest(requestInfo);
    }

    // Continue request
    request.continue();
  });

  // Monitor responses with enhanced parsing
  page.on('response', async (response) => {
    const url = response.url();
    const status = response.status();
    
    // Match response to request
    const matchingRequest = capturedRequests.find(r => r.url === url && !r.response);
    
    if (matchingRequest) {
      try {
        let responseText = '';
        let responseType = 'unknown';
        
        // Try to get response body
        try {
          responseText = await response.text();
          responseType = 'text';
        } catch (e) {
          // Some responses don't have text bodies
          try {
            const buffer = await response.buffer();
            responseText = `[Binary data: ${buffer.length} bytes]`;
            responseType = 'binary';
          } catch (e2) {
            responseText = '[No response body available]';
            responseType = 'empty';
          }
        }
        
        matchingRequest.response = {
          status,
          headers: response.headers(),
          body: responseText,
          type: responseType,
          fullLength: responseText.length
        };
        
        // Enhanced response logging
        if (matchingRequest.isBillingRequest) {
          console.log(chalk.red.bold(`   ↩️  BILLING RESPONSE [${matchingRequest.id}]:`));
        } else {
          console.log(chalk.blue(`   ↩️  Response [${matchingRequest.id}]:`));
        }
        
        console.log(chalk.gray(`   Status: ${status}`));
        
        // Parse and display response based on content type
        const contentType = response.headers()['content-type'] || '';
        
        if (contentType.includes('json')) {
          try {
            const jsonResponse = JSON.parse(responseText);
            console.log(chalk.yellow('   JSON Response:'));
            console.log(chalk.gray(JSON.stringify(jsonResponse, null, 2).substring(0, 500)));
            
            // Check for success/error indicators
            if (jsonResponse.success !== undefined) {
              console.log(chalk[jsonResponse.success ? 'green' : 'red'](`   Success: ${jsonResponse.success}`));
            }
            if (jsonResponse.error || jsonResponse.message) {
              console.log(chalk.cyan(`   Message: ${jsonResponse.error || jsonResponse.message}`));
            }
          } catch (e) {
            // Not valid JSON
          }
        } else if (responseText.includes('<html') || responseText.includes('<div')) {
          console.log(chalk.gray('   HTML Response (first 300 chars):'));
          console.log(chalk.gray(responseText.substring(0, 300).replace(/\n/g, ' ')));
        } else if (responseType === 'text') {
          console.log(chalk.gray('   Text Response (first 300 chars):'));
          console.log(chalk.gray(responseText.substring(0, 300)));
        }
        
        // Special handling for billing responses
        if (matchingRequest.isBillingRequest) {
          // Look for success patterns
          if (responseText.includes('success') || responseText.includes('activated') || responseText.includes('тариф')) {
            console.log(chalk.bgGreen.black(' ✅ POSSIBLE SUCCESS RESPONSE DETECTED '));
          }
          if (responseText.includes('error') || responseText.includes('fail') || responseText.includes('denied')) {
            console.log(chalk.bgRed.white(' ❌ ERROR RESPONSE DETECTED '));
          }
        }
        
        // Update saved request with response
        await saveRequest(matchingRequest);
      } catch (e) {
        console.log(chalk.red(`   ⚠️  Could not read response: ${e.message}`));
      }
    }
  });

  try {
    // Navigate to login page
    console.log(chalk.blue('\n📍 Navigating to login page...'));
    await page.goto(CONFIG.loginUrl, { waitUntil: 'networkidle2' });
    
    // Wait a moment for page to load
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Try to find and fill login form
    console.log(chalk.blue('🔐 Attempting to login...'));
    
    // Try different possible selectors for username field
    const usernameSelectors = [
      'input[name="login_name"]',
      'input[name="username"]',
      'input[name="login"]',
      'input[type="text"]',
      '#login_name',
      '#username',
      '#login'
    ];
    
    const passwordSelectors = [
      'input[name="login_password"]',
      'input[name="password"]',
      'input[name="pass"]',
      'input[type="password"]',
      '#login_password',
      '#password',
      '#pass'
    ];
    
    let loginSuccess = false;
    
    for (const selector of usernameSelectors) {
      try {
        await page.waitForSelector(selector, { timeout: 1000 });
        await page.type(selector, CONFIG.username);
        console.log(chalk.green(`   ✓ Username entered using: ${selector}`));
        loginSuccess = true;
        break;
      } catch (e) {
        // Try next selector
      }
    }
    
    if (loginSuccess) {
      loginSuccess = false;
      for (const selector of passwordSelectors) {
        try {
          await page.waitForSelector(selector, { timeout: 1000 });
          await page.type(selector, CONFIG.password);
          console.log(chalk.green(`   ✓ Password entered using: ${selector}`));
          loginSuccess = true;
          break;
        } catch (e) {
          // Try next selector
        }
      }
    }
    
    if (loginSuccess) {
      // Try to find and click login button
      const buttonSelectors = [
        'button[type="submit"]',
        'input[type="submit"]',
        'button:contains("Login")',
        'button:contains("Sign in")',
        'button:contains("Войти")',
        '.btn-login',
        '#login-button'
      ];
      
      for (const selector of buttonSelectors) {
        try {
          await page.click(selector);
          console.log(chalk.green(`   ✓ Login button clicked: ${selector}`));
          break;
        } catch (e) {
          // Try next selector
        }
      }
      
      // Wait for navigation
      await new Promise(resolve => setTimeout(resolve, 3000));
      console.log(chalk.green('   ✓ Login submitted, waiting for redirect...'));
    } else {
      console.log(chalk.yellow('   ⚠️  Could not auto-login. Please login manually in the browser.'));
    }
    
    // Instructions for manual interaction
    console.log(chalk.cyan.bold('\n📋 Instructions:'));
    console.log(chalk.white('1. If not logged in, please login manually'));
    console.log(chalk.white(`2. Navigate to Users/Dillers section`));
    console.log(chalk.white(`3. Find user: ${CONFIG.targetUsername} (ID: ${CONFIG.targetUserId})`));
    console.log(chalk.white('4. Click on subscription/tariff activation buttons'));
    console.log(chalk.white('5. Try different periods: 1-month, 3-month, 12-month'));
    console.log(chalk.white('6. All network requests will be captured automatically'));
    console.log(chalk.white('7. Press Ctrl+C when done to save all requests\n'));
    
    // Keep monitoring
    console.log(chalk.green.bold('🎯 Monitoring active! All requests are being captured...\n'));
    console.log(chalk.gray('='). repeat(80));
    
  } catch (error) {
    console.error(chalk.red('Error during setup:'), error);
  }
  
  // Handle graceful shutdown with enhanced summary
  process.on('SIGINT', async () => {
    console.log(chalk.yellow('\n\n📊 Generating comprehensive report...'));
    
    // Save detailed summary
    const summaryFile = path.join(CONFIG.outputDir, 'summary.json');
    const timestamp = new Date().toISOString();
    
    // Analyze captured data
    const billingRequests = capturedRequests.filter(r => r.isBillingRequest);
    const ajaxRequests = capturedRequests.filter(r => r.url.includes('/ajax/'));
    const postRequests = capturedRequests.filter(r => r.method === 'POST');
    const successfulRequests = capturedRequests.filter(r => r.response?.status === 200);
    
    // Group by module
    const moduleGroups = {};
    capturedRequests.forEach(req => {
      if (req.module) {
        if (!moduleGroups[req.module]) {
          moduleGroups[req.module] = [];
        }
        moduleGroups[req.module].push(req);
      }
    });
    
    // Group by clicked elements
    const clickGroups = {};
    capturedRequests.forEach(req => {
      if (req.triggeredBy?.text) {
        const key = req.triggeredBy.text;
        if (!clickGroups[key]) {
          clickGroups[key] = [];
        }
        clickGroups[key].push(req);
      }
    });
    
    const summary = {
      captureSession: {
        timestamp,
        duration: Date.now() - new Date(capturedRequests[0]?.timestamp || Date.now()).getTime(),
        totalRequests: capturedRequests.length,
        config: CONFIG
      },
      statistics: {
        totalRequests: capturedRequests.length,
        billingRequests: billingRequests.length,
        ajaxRequests: ajaxRequests.length,
        postRequests: postRequests.length,
        successfulRequests: successfulRequests.length,
        moduleBreakdown: Object.keys(moduleGroups).map(mod => ({
          module: mod,
          count: moduleGroups[mod].length
        }))
      },
      billingEndpoints: billingRequests.map(r => ({
        id: r.id,
        url: r.url,
        method: r.method,
        module: r.module,
        plugin: r.plugin,
        postData: r.postData,
        responseStatus: r.response?.status,
        triggeredBy: r.triggeredBy?.text || r.triggeredBy?.onclick
      })),
      clickActions: Object.keys(clickGroups).map(click => ({
        buttonText: click,
        requestsTriggered: clickGroups[click].length,
        endpoints: clickGroups[click].map(r => `${r.method} ${r.module || r.url.split('?')[0]}`)
      })),
      allRequests: capturedRequests
    };
    
    await fs.writeJson(summaryFile, summary, { spaces: 2 });
    
    console.log(chalk.green(`✅ Saved ${capturedRequests.length} requests to ${summaryFile}`));
    
    // Enhanced console summary
    console.log(chalk.cyan.bold('\n🎯 CAPTURE SUMMARY'));
    console.log(chalk.gray('='.repeat(60)));
    
    console.log(chalk.white('\n📊 Statistics:'));
    console.log(chalk.gray(`   Total Requests: ${capturedRequests.length}`));
    console.log(chalk.gray(`   Billing Requests: ${billingRequests.length}`));
    console.log(chalk.gray(`   POST Requests: ${postRequests.length}`));
    console.log(chalk.gray(`   Successful (200): ${successfulRequests.length}`));
    
    // Show module breakdown
    if (Object.keys(moduleGroups).length > 0) {
      console.log(chalk.white('\n📦 Modules Found:'));
      Object.entries(moduleGroups).forEach(([mod, reqs]) => {
        const isNew = mod === 'BillingTariff';
        const color = isNew ? 'red' : 'gray';
        const marker = isNew ? ' 🎯 NEW!' : '';
        console.log(chalk[color](`   ${mod}: ${reqs.length} requests${marker}`));
        
        // Show unique plugins for this module
        const plugins = [...new Set(reqs.map(r => r.plugin).filter(Boolean))];
        if (plugins.length > 0) {
          console.log(chalk.gray(`     Plugins: ${plugins.join(', ')}`));
        }
      });
    }
    
    // Show billing-specific findings
    if (billingRequests.length > 0) {
      console.log(chalk.red.bold('\n⚡ BILLING ENDPOINTS DISCOVERED:'));
      
      // Group by unique endpoint patterns
      const uniqueEndpoints = {};
      billingRequests.forEach(req => {
        const key = `${req.method} ${req.module || 'unknown'}/${req.plugin || 'unknown'}`;
        if (!uniqueEndpoints[key]) {
          uniqueEndpoints[key] = {
            example: req,
            count: 0,
            statuses: []
          };
        }
        uniqueEndpoints[key].count++;
        if (req.response?.status) {
          uniqueEndpoints[key].statuses.push(req.response.status);
        }
      });
      
      Object.entries(uniqueEndpoints).forEach(([pattern, data]) => {
        const isNew = pattern.includes('BillingTariff');
        console.log(chalk[isNew ? 'bgRed' : 'yellow'](` ${pattern} `) + chalk.gray(` (${data.count} calls)`));
        
        if (data.example.postData) {
          console.log(chalk.gray('   Sample POST data:'));
          const params = new URLSearchParams(data.example.postData);
          for (const [key, value] of params) {
            console.log(chalk.gray(`     ${key}: ${value}`));
          }
        }
        
        if (data.statuses.length > 0) {
          const uniqueStatuses = [...new Set(data.statuses)];
          console.log(chalk.gray(`   Response statuses: ${uniqueStatuses.join(', ')}`));
        }
        
        if (data.example.triggeredBy?.text) {
          console.log(chalk.blue(`   Triggered by: "${data.example.triggeredBy.text}"`))
        }
        console.log();
      });
    }
    
    // Show click action summary
    if (Object.keys(clickGroups).length > 0) {
      console.log(chalk.magenta.bold('\n👆 USER ACTIONS SUMMARY:'));
      Object.entries(clickGroups).slice(0, 5).forEach(([click, reqs]) => {
        console.log(chalk.white(`   "${click}": ${reqs.length} requests`));
      });
    }
    
    console.log(chalk.gray('\n='.repeat(60)));
    console.log(chalk.green.bold('\n✅ Full report saved to: ' + summaryFile));
    console.log(chalk.yellow('\n💡 Next steps:'));
    console.log(chalk.gray('   1. Review summary.json for complete details'));
    console.log(chalk.gray('   2. Look for BillingTariff module requests (NEW endpoints)'));
    console.log(chalk.gray('   3. Compare old BillingAjax vs new BillingTariff patterns'));
    console.log(chalk.gray('   4. Check response bodies for success/error patterns\n'));
    
    await browser.close();
    process.exit(0);
  });
}

// Save individual request to file
async function saveRequest(requestInfo) {
  const filename = `request-${requestInfo.id}-${requestInfo.method}-${Date.now()}.json`;
  const filepath = path.join(CONFIG.outputDir, filename);
  await fs.writeJson(filepath, requestInfo, { spaces: 2 });
}

// Start the monitoring
startMonitoring().catch(error => {
  console.error(chalk.red('Fatal error:'), error);
  process.exit(1);
});