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


bot.bucket :ping, limit: 2, time_span: 60, delay: 30

TURTLE_EMOJI = "🐢".freeze
CHECK_MARK = "✅".freeze 
X_EMOJI = "❌".freeze

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



market = DB[:market]
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
        end
        sleep(3)

        em.delete
    end
    nil
end

bot.command(:eval, help_available: false) do |event, *code|
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

bot.command(:exec, help_available: false) do |event, *command|
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
            embed.add_field(name: "Seller Name: ", value: "#{user.name}##{user.id}", inline: true)
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
- The SellerID is the UserID of the seller/offerer
Conforming with above, usage follows:
`list [SellerID]|[Buy/Sell]|[Price]|[Title]|[Description]`

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

bot.run