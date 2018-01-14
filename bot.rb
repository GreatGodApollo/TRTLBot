#   bot.rb
#   Written by Brett Bender 2018
#   A bot for the TRTL server to add listings to the #turtle-market channel
#

require 'discordrb'
require 'sequel'
require 'json'



# Json stuffs
configfile = File.read("config.json")
config = JSON.parse(configfile)



if config['token'] == nil || config['prefix'] == nil || config['clientid'] == nil || config['role'] == nil
    exit
end



ROLENAME = config["role"]
DB = Sequel.connect('sqlite://trtl.db') 

# Define the bot
bot = Discordrb::Commands::CommandBot.new(token: config["token"], client_id: config["clientid"], prefix: config["prefix"])
adminbot = Discordrb::Commands::CommandBot.new(token: config["token"], client_id: config["clientid"], prefix: config["adminprefix"])

bot.bucket :ping, limit: 2, time_span: 60, delay: 30

TURTLE_EMOJI = "🐢".freeze
CHECK_MARK = "✅".freeze 
X_EMOJI = "❌".freeze

disabled = []

DB.create_table? :market do 
    primary_key :id
    Integer :userid
    Boolean :buy
    Boolean :sell
    String :price
    String :title
    String :desc
    Integer :messageid
end

DB.create_table? :wallets do
    primary_key :id
    String :address
    Integer :userid
    Integer :messageid
    String :deposit
end

DB.create_table? :disabled do
    primary_key :id
    String :command
    Boolean :disabled
end


market = DB[:market]
wallets = DB[:wallets]
disabled = DB[:disabled]
class Market < Sequel::Model(DB[:market]); end


bot.command(:ping, bucket: :ping, rate_limit_message: 'Calm down for %time% more seconds!', help_available: false) do |event|
    m = event.respond("Sending Explosion!💣")
    m.edit("💥Explosion Received in: #{m.timestamp - Time.now}ms 💥")
end

bot.command(:pong, help_available: false) do |event|
    event.message.react(TURTLE_EMOJI)
    bot.add_await(:"secret_#{event.message.id}", Discordrb::Events::ReactionAddEvent, emoji: TURTLE_EMOJI) do |reaction_event|
        next true unless reaction_event.message.id == event.message.id
        next true unless reaction_event.user.id == event.user.id
        event.message.delete_own_reaction(TURTLE_EMOJI)

        em = event.channel.send_embed do |embed|
            embed.title = "You found a secret!"
            embed.colour = 0xD4AF37
            embed.description = "Don't tell anyone how you did this"
            embed.image = Discordrb::Webhooks::EmbedImage.new(url: "https://fthmb.tqn.com/UtCkhoQca0ZSpWZNBn39e-f0xnc=/2116x1417/filters:fill(auto,1)/Pet-turtle-GettyImages-163253309-58da61e53df78c516256c1c6.jpg")
        end
        sleep(3)

        em.delete
    end
    nil
end

adminbot.command(:eval, help_available: false) do |event, *code|
    break unless event.user.id == config["owner"]
  
    begin
        event.channel.send_embed do |embed|
            embed.add_field(name: "Input: ", value: "#{code.join(' ')}")
            embed.add_field(name: "Output: ", value: "```#{eval code.join(' ')}```")
            embed.colour = 0x01960d
        end
    rescue
        'An error occurred 😞'
    end
end

adminbot.command(:exec, help_available: false) do |event, *command|
    break unless event.user.id == config["owner"]

    begin
        eval "`#{command.join(' ')}`"
    rescue
        'An error occured'
    end
end

bot.command(:list, usage: config["prefix"] + "list [mention]|[buy or sell]|[price]|[title]|[description]", description: "Add a listing in #turtle-market\nYou MUST use the `|` inbetween the args") do |event, *args|
    s = event.server
    memb = s.member(event.user.id)
    for r in memb.roles
        if r.name == "@trader"
            good = true
            break
        else
            good = false
        end
    end
    if good
        # Add a listing
        if args != nil
            
            for r in memb.roles
                if r.name == config["role"]
                    good = true
                    break
                else
                    good = false
                end
            end

            arg = args.join(' ')
            split = arg.split('|')
            ment = split[0]
            bs = split[1]
            pr = split[2]
            tt = split[3]
            dc = split[4]
            
            if ment == nil || bs == nil || pr == nil || tt == nil || dc == nil
                supplied = false
            else
                supplied = true
            end

            if supplied
                # Continues to add the listing
                if bs.downcase == "buy" || bs.downcase == "offer" || bs.downcase == "b"
                    b = true
                    se = false
                elsif bs.downcase == "sell" || bs.downcase == "asking" || bs.downcase == "s"
                    b = false
                    se = true
                end


                if b == true
                    pre = "[BUY]"
                elsif se == true
                    pre = "[SELL]"
                end

                user = bot.parse_mention(ment)
                
                if user != nil
                    id = user.id

                    event.server.text_channels.each do |chan|
                        channame = chan.name
                        chanid = chan.id
                        if channame == "turtle-market"
                            listing = market.insert(userid: id, buy: b, sell: se, price: pr, title: tt, desc: dc, messageid: 0)
                            emb = chan.send_embed do |embed|
                                embed.title = "Listing " + listing.to_s + ": " + pre + " " + tt
                                embed.colour = 0x00843D
                                embed.description = dc
                                embed.add_field(name: "Price: ", value: pr)
                                embed.add_field(name: "Seller ID: ", value: id.to_s, inline: true)
                                embed.add_field(name: "Seller name: ", value: "#{user.name}##{user.discriminator}", inline: true)
                            end
                            market.where(:id => listing).update(messageid: emb.id)
                            break
                        end
                    end
                else
                    event.respond "Invalid Mention"
                end
            else
                event.respond "Invalid number of args supplied"
            end
        else
            event.respond "You must supply arguments"
        end
    else
        event.respond "Invalid Permissions"
    end
    nil
end

bot.command(:listing, usage: config["prefix"] + "listing [id]", description: "Get information on the listing") do |event, id|
    ido = id.to_i
    listing = market.where(id: id)
    if listing.get(:title) != nil
        if listing.get(:buy)
            pre = "**[BUY]**"
        else
            pre = "**[SELL]**"
        end
        userid = listing.get(:userid)
        mention = "<@!#{userid}>"
        user = bot.parse_mention(mention)

        event.channel.send_embed do |embed|
            embed.title = "Listing " + listing.get(:id).to_s + ": " + pre + " " + listing.get(:title)
            embed.colour = 0x00843D
            embed.description = listing.get(:desc)
            embed.add_field(name: "Price: ", value: listing.get(:price))
            embed.add_field(name: "Seller ID: ", value: listing.get(:userid).to_s, inline: true)
            embed.add_field(name: "Seller Name: ", value: "#{user.name}##{user.discriminator}", inline: true)
        end
    else
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "The listing ID #{id} is not valid"
            embed.colour = 0xef0000
        end
    end
end

bot.command(:unlist, usage: config["prefix"] + "unlist [listing id]", description: "Remove a listing") do |event, id|
    s = event.server
    memb = s.member(event.user.id)
    for r in memb.roles
        if r.name == config["role"]
            good = true
            break
        else
            good = false
        end
    end

    if good
        if id != nil
            listing = market.where(id: id)
            messageid = listing.get(:messageid)
            if messageid != nil
                event.channel.send_embed do |embed|
                    embed.title = "Confirm action"
                    embed.description = "Are you sure you want to delete listing ##{id}\n(Respond with `yes` or `no`)"
                    embed.colour = 0x00843D
                end
                event.user.await(:"unlist_#{event.user.id}") do |await_event|
                    next true unless await_event.channel.id == event.channel.id
                    reply = await_event.message.content.downcase
                    if reply == "yes" || reply == "y"
                        
                        event.server.text_channels.each do |chan|
                            channame = chan.name
                            chanid = chan.id
                            if channame == "turtle-market"
                                chan.delete_message(messageid)
                                listing.delete
                                event.channel.send_embed do |embed|
                                    embed.title = "Action confirmed"
                                    embed.description = "The listing has been removed"
                                    embed.colour = 0x00843D
                                end
                                break
                            end
                        end
                        
                    elsif reply == "no" || reply == "n"
                        event.respond "Action Aborted"
                    else
                    end
                end
            else 
                event.channel.send_embed do |embed|
                    embed.title = ":x:Error:x:"
                    embed.description = "Invalid ID"
                    embed.colour = 0xef0000
                end
            end
        else
            event.channel.send_embed do |embed|
                embed.title = ":x:Error:x:"
                embed.description = "Please supply an ID"
                embed.colour = 0xef0000
            end
        end
        
    else
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Invalid Permissions"
            embed.colour = 0xef0000
        end
    end
    nil
end



bot.command(:guide, usage: config["prefix"] + "guide", description: "Learn how to use #{config["prefix"]}list and #{config["prefix"]}unlist") do |event|
    event.channel.send_embed do |embed|
        embed.title = "Usage"
        embed.description = 
"Learn to use list and unlist.
(list will eventually be more user friendly, just trying to figure out how to make a chain of inputs)

**list:**
To use list you require the `@trader` role
Users with the `@trader` role may use list conforming to the following:
- In between args you **__MUST__** use `|`
- The Mention is the @ of the seller (Actually mention them)
Conforming with above, usage follows:
`list [Mention]|[Buy/Sell]|[Price]|[Title]|[Description]`

**unlist:**
To use unlist you require the `@trader` role
Users with the `@trader` role may use unlist conforming to the following:
- The ID is the Listing ID on the top of the listing (Listing [ID HERE]: ...)
Conforming with above, usage follows
`unlist [ID]`

After using the command, you must confirm your action by typing `yes` or cancel by typing `no`
After confirming the listing and DB entry will be deleted
"
        embed.colour = 0x00843D
    end
end

bot.command(:registerwallet, usage: config["prefix"] + "registerwallet [Address]") do |event, wallet|
    if wallet == nil 
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x"
            embed.description = "Please provide an address"
            embed.colour = 0xef0000
        end
    elsif wallets.where(userid: event.user.id).get(:address) == nil && wallet.length == 99 && wallet.start_with?("TRTL")
        event.server.text_channels.each do |chan|
            channame = chan.name
            chanid = chan.id
            if channame == "wallets"
                listing = wallets.insert(userid: event.user.id, address: wallet, messageid: 0)
                em = chan.send_embed do |embed|
                    embed.title = "#{event.user.name}##{event.user.discriminator}'s Wallet"
                    embed.description = "#{wallet}\nDB Listing ID: #{listing}"
                    embed.color = 0xD4AF37
                end
                wallets.where(id: listing).update(messageid: em.id)
                break
            end
        end
    elsif wallet.length > 99
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Your wallet must be 99 characters long, your entry was too long"
            embed.colour = 0xef0000
        end
    elsif wallet.length < 99
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "You wallet must be 99 characters long, your entry was too short"
            embed.colour = 0xef0000
        end
    elsif !wallet.start_with?("TRTL")
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Wallets start with `TRTL`"
            embed.colour = 0xef0000
        end
    else
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "You have already submitted a wallet"
            embed.colour = 0xef0000
        end
    end
    nil
end

bot.command(:wallet, usage: config["prefix"] + "wallet [User Mention]") do |event, mention|
    if mention != ""
        user = bot.parse_mention(mention)
        if wallets.where(userid: user.id).get(:address) != nil
            event.channel.send_embed do |embed|
                embed.title = "#{user.name}##{user.discriminator}'s Wallet"
                embed.description = "#{wallets.where(userid: user.id).get(:address)}"
                embed.colour = 0xD4AF37
            end
        else
            event.channel.send_embed do |embed|
                embed.title = ":x:Error:x:"
                embed.description = "#{user.name}##{user.discriminator} Has not submitted a wallet"
                embed.colour = 0xef0000
            end
        end
    else
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Please mention someone"
            embed.colour = 0xef0000
        end
    end
end

bot.command(:updatewallet) do |event, wallet|
    if wallets.where(userid: event.user.id).get(:address) == nil
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "You currently don't have a wallet, please submit one with `!registerwallet`"
            embed.colour = 0xef0000
        end
    elsif wallets.where(userid: event.user.id).get(:address) == wallet
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Your wallet is already #{wallet}"
            embed.colour = 0xef0000
        end
    elsif wallet == nil
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Please supply a wallet!"
            embed.colour = 0xef0000
        end
    elsif wallets.where(userid: event.user.id).get(:address) != nil && wallet.length == 99 && wallet.start_with?("TRTL")
        walletf = wallets.where(userid: event.user.id)
        event.channel.send_embed do |embed|
            embed.title = "Your wallet has been changed"
            embed.description = wallet
            embed.colour = 0x01960d
        end
        walletf.update(address: wallet)
    elsif wallet.length < 99
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Your wallet must be 99 characters long, your entry was too short"
            embed.colour = 0xef0000
        end
    elsif wallet.length > 99
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Your wallet must be 99 characters long, your entry was too long"
            embed.colour = 0xef0000
        end
    elsif !wallet.start_with?("TRTL")
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Wallets start with `TRTL`"
            embed.colour = 0xef0000
        end
    end 
end

bot.command(:tipowner) do |event|
    event.channel.send_embed do |embed|
        embed.title = "So you want to tip the bot owner eh?"
        embed.description = "If you want to tip the creator of TRTLBot, you can use this address:\n\nTRTLuwWtVeb5jWX1ewfH92dwt7dLr7YEgevfoHRvWjDxMwYGHqKBWT62vND587z5h9X7WYH7gy8DN56QkCebUXjkhrNMebuGWf9\n\nIf you would like to tip the creator of TurtleBot, you can use this address:\n\nTRTLuzVNVhSZaUbmqp5DiC8esAhpXLQgzYPKAjtGHDCVKsSBoEBfftZMabFxDekEAT6hDkyD8LRzyb8zi7yEqgmm9152SDxCHZX"
        embed.colour = 0x01960d
    end
end

bot.command(:deposit) do |event|
    user = event.user
    if wallets.where(userid: event.user.id).get(:address) != nil
        event.user.pm.send_embed do |embed|
            embed.title = "Adding TRTL to your tipping address"
            embed.description = "To add money to your tipping address send TRTL here:\n#{wallets.where(userid: user.id).get(:deposit)}"
            embed.colour = 0x01960d
        end
    else
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "You don't have a wallet submitted!"
            embed.colour = 0xef0000
        end
    end
end



bot.run(async: true)
adminbot.run
