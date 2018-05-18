# TRTLBot
A bot made by `apollo#9292` for the TRTL Discord Server

Note: This bot is not in use anymore so in order to see what it does you must run it yourself. Due to this I am no longer providing support for the bot, use at your own risk.

# Commands
- `help` - List all available commands
- `price` - Get the current price of TRTL
- `o` - Owner Commands
  - `o eval` - Evaluate ruby code
  - `o exec` - Execute a command line program
  - `o shutdown` - Shutdown the bot
  - `o bc` - Broadcast a message to the servers the bot is on
- `faucet` - Get the amount of TRTLs left in the faucet
- `ping` - Check if the bot is alive
- `registerwallet` - Register your wallet in the DB and send it to the wallets channel
- `wallet` - Check the wallet of somebody
- `updatewallet` - Change your wallet entry (does not send to wallets channel)
- `tipowner` - Provides TRTL addresses to tip the creators of the bots
- `suggesst` - Provide a suggestion for a feature

# Internals
The bot runs on DiscordRB (inheritly Ruby), Sequel, and HTTParty.
DiscordRB is for connecting to Discord, Sequel is for connecting to the DB, and HTTParty is for connecting to external APIs.

# Configuration
Copy the contents of `config.json.example` to `config.json`
```json
{
    "token":"Token",
    "clientid":"Bot Client ID", //Insert the bots ID here
    "owner":"Owner Client ID", //Insert your ID here
    "prefix":"."
}
```

# Running
Just `ruby bot.rb`. Thats how easy it is!
