# Hubot API
Robot        = require('hubot').Robot
Adapter      = require('hubot').Adapter
TextMessage  = require('hubot').TextMessage

# Node API
HTTP         = require('http')
EventEmitter = require('events').EventEmitter

# Faye connector
Faye         = require('faye')

class Kandan extends Adapter

  send: (user, strings...) ->
    if strings.length > 0
      callback = errback = (response) => @send user, strings...
      @bot.message strings.shift(), user?.room?.id || 1, callback, errback

  run: ->
    options =
      host:     process.env.HUBOT_KANDAN_HOST
      port:     process.env.HUBOT_KANDAN_PORT || 80
      token:    process.env.HUBOT_KANDAN_TOKEN

    @bot = new KandanStreaming(options, @robot)
    callback = (myself) =>
      @bot.on "TextMessage", (message) =>
        unless myself.id == message.user.id
          message.user.room = message.channel
          @receive new TextMessage(message.user, message.content)
      @emit "connected"
    errback = (response) =>
      throw new Error "Unable to determine profile information."

    @bot.Me callback, errback

exports.use = (robot) ->
  new Kandan robot

class KandanStreaming extends EventEmitter
  constructor: (options, robot) ->
    @eventProcessors = {
      user: {}
      channel: {
        delete: (data) => @unsubscribe(data.entity.id)
        create: (data) => @subscribe(data.entity.id)
      }
      attachments: {}
    }

    unless options.token? and options.host?
      robot.logger.error "Not enough parameters provided. I need a host and token."
      process.exit(1)

    @host     = options.host
    @port     = options.port
    @token    = options.token

    @logger = robot.logger

    target = "http://#{ @host }:#{ @port }/remote/faye"
    robot.logger.info("Connecting to #{ target }")

    @client = new Faye.Client(target)
    @client.disable('websocket')
    authExtension = {
      outgoing: (message, callback) =>
        if message.channel == "/meta/subscribe"
          message['ext'] = { auth_token: @token }
        callback(message)
    }
    @client.addExtension(authExtension)

    @client.bind "transport:up", () =>
      robot.logger.info "Connected to Faye server"

    @client.bind "transport:down", () =>
      robot.logger.error "Disconnected from Faye server"

    @subscribeEvents()
    # Always subscribe to the primary channel
    @subscribe(1)
    # Subscribe to all the other channels
    callback = (channels) =>
      for channel in channels
        @subscribe(channel.id) unless channel.id == 1
    errback = (err) =>
      @logger.warn "Error retrieving channels list; will only listen on primary channel"
    @Channels callback, errback
    @

  subscribeEvents: ->
    @client.subscribe "/app/activities", (data) =>
      [entityName, eventName] = data.event.split("#")
      @eventProcessors[entityName]?[eventName]?(data)

  unsubscribe: (channelId) ->
    @logger.debug "Unsubscribing from channel: #{channelId}"
    @client.unsubscribe "/channels/#{channelId}"

  subscribe: (channelId) ->
    @logger.debug "Subscribing to channel: #{channelId}"
    subscription = @client.subscribe "/channels/#{channelId}", (activity) =>
      eventMap =
        'enter':   'EnterMessage'
        'leave':   'LeaveMessage'
        'message': 'TextMessage'
      @emit eventMap[activity.action], activity
    subscription.errback((activity) =>
      @logger.error activity
      @logger.error "Oops! could not connect to the server"
    )

  message: (message, channelId, callback, errback) ->
    body = {
      content: message
      channel_id: channelId
      activity: {
        content: message,
        channel_id: channelId,
        action: "message"
      }
    }
    @post "/channels/#{ channelId }/activities", body, callback, errback

  Channels: (callback, errback) ->
    @get "/channels", callback, errback

  # Needs to be implemented in Kandan
  User: (id, callback, errback) ->
    @get "/active_users.json", callback, errback

  Me: (callback, errback) ->
    @get "/me", callback, errback

  Channel: (id) =>
    logger = @logger

    show: (callback, errback) ->
      @post "/channels/#{id}", "", callback, errback

    join: (callback, errback) ->
      logger.info "Join is a NOOP on Kandan right now"

    leave: (callback, errback) ->
      logger.info "Leave is a NOOP on Kandan right now"


  get: (path, callback, errback) ->
    @request "GET", path, null, callback, errback

  post: (path, body, callback, errback) ->
    @request "POST", path, body, callback, errback

  request: (method, path, body, callback, errback) ->
    logger = @logger

    headers =
      "Content-Type" : "application/json"
      "Accept"       : "application/json"

    options =
      "agent"   : false
      "host"    : @host
      "port"    : @port
      "path"    : path
      "method"  : method
      "headers" : headers

    if method is "POST" || method is "PUT"
      body.auth_token = @token
      if typeof(body) isnt "string"
        body = JSON.stringify(body)

      body = new Buffer(body)
      options.headers["Content-Length"] = body.length
    else
      options.path += "?auth_token=#{@token}"

    request = HTTP.request options, (response) ->
      data = ""

      response.on "data", (chunk) ->
        data += chunk

        response.on "end", ->
          if response.statusCode >= 400
            switch response.statusCode
              when 401
                throw new Error "Invalid access token provided, Kandan refused the authentication"
              else
                logger.error "Kandan error: #{response.statusCode}"
            errback(response) if errback?
            return

          try
            callback JSON.parse(data) if callback?
          catch err
            errback(err) if errback?

    if method is "POST" || method is "PUT"
      request.end(body, 'binary')
    else
      request.end()

    request.on "error", (err) ->
      logger.error "Kandan request error: #{err}"
      errback(response) if errback?
