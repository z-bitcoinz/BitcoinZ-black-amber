# Network Monitor for IPTV Provider API

This tool monitors and captures all network requests made to the IPTV provider's backend, specifically designed to discover the new API endpoints for subscription activation.

## Features

- 🚀 Automated browser launch with DevTools
- 🔐 Auto-login capability
- 📡 Real-time network request monitoring
- 🎯 Filters and highlights billing-related requests
- 💾 Saves all requests to JSON files
- 🔍 Parses and displays request/response data
- 📊 Generates summary report

## Installation

```bash
cd network-monitor
npm install
```

## Usage

### Quick Start

```bash
npm start
```

This will:
1. Open Chrome browser with DevTools
2. Navigate to the provider's login page
3. Attempt auto-login with configured credentials
4. Start monitoring all network requests

### Manual Steps After Launch

1. **If auto-login fails**, manually login with:
   - Username: `Simbav911`
   - Password: `8g9a505hfh8`

2. **Navigate to Users/Dillers section**

3. **Find the test user**:
   - Username: `prov_lilija1000_31194`
   - User ID: `46259`

4. **Click subscription activation buttons**:
   - Try 1-month subscription
   - Try 3-month subscription
   - Try 12-month subscription
   - Try 24-hour test activation (if available)

5. **Monitor the console output** - all requests are logged in real-time

6. **Press Ctrl+C** when done to save all captured requests

## What Gets Captured

The tool specifically monitors:
- All AJAX requests (`/ajax/`)
- Controller requests (`controller.php`)
- Billing-related requests (containing "Billing" or "Tariff")
- All POST requests (excluding CSS/JS files)
- API endpoints (`/api/`)

For each request, it captures:
- Full URL with parameters
- HTTP method (GET/POST)
- Request headers
- POST data/payload
- Response status
- Response body (first 1000 chars)

## Output Files

All captured data is saved to `./captured-requests/`:

- **Individual requests**: `request-{id}-{method}-{timestamp}.json`
- **Summary file**: `summary.json` (contains all requests)

## Key Endpoints to Look For

Based on the provider's system, watch for:

### Old (Not Working)
```
mod=BillingAjax&plugin=tariff
```

### New (Expected)
```
mod=BillingTariff&plugin=TariffSelect
```

## Console Output

The tool uses color-coded output:
- 🚀 Blue: Navigation and setup
- 📡 Green: Captured requests
- 🔍 Magenta: Module/Plugin info
- 📊 Yellow: POST data and parameters
- ↩️  Blue: Response data
- ⚠️  Red: Errors

## Analyzing Results

After capturing, look for:

1. **Successful activation requests** (status 200)
2. **Required parameters** (tariff_id, user_id, days, etc.)
3. **Authentication headers** (cookies, tokens)
4. **Response format** (JSON success indicators)

## Example Captured Request

```json
{
  "id": 1,
  "timestamp": "2024-01-10T12:00:00Z",
  "url": "https://streaming-elbrus.su/engine/ajax/controller.php?mod=BillingTariff&plugin=TariffSelect",
  "method": "POST",
  "headers": {
    "cookie": "session=xyz123",
    "x-requested-with": "XMLHttpRequest"
  },
  "postData": "tariff_id=17&user_id=46259&days=30",
  "response": {
    "status": 200,
    "body": "{\"success\":true,\"message\":\"Subscription activated\"}"
  }
}
```

## Troubleshooting

- **Browser doesn't open**: Check if Chrome is installed
- **Login fails**: Check credentials or login manually
- **No requests captured**: Check DevTools Network tab is active
- **Requests missing**: Clear browser cache and try again

## Configuration

Edit `network-monitor.js` CONFIG object to change:
- Login URL
- Credentials
- Target user info
- Output directory
- Browser settings (headless, devtools)