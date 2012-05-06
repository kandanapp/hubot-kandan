Robot        = require '../robot'
Adapter      = require '../adapter'

HTTP        = require 'http'
EventEmitter = require('events').EventEmitter

Faye = require('faye')

class Kandan extends Adapter

  send: (user, strings...) ->
    if strings.length > 0
      @bot.message strings.shift(), 1, (err, data) =>
        @robot.logger.error "Kandan error: #{err}" if err?
        @send user, strings...

  run: ->
    self = @

    options =
      host:     process.env.HUBOT_KANDAN_HOST
      port:     process.env.HUBOT_KANDAN_PORT || 80
      token:    process.env.HUBOT_KANDAN_TOKEN
      channels: process.env.HUBOT_KANDAN_CHANNELS

    @bot = new KandanStreaming(options, @robot)

    @bot.on "TextMessage", (message) ->
      unless message.user_id == 4
        self.receive new Robot.TextMessage(message.user.email, message.content)

    self.emit "connected"

exports.use = (robot) ->
  new Kandan robot

class KandanStreaming extends EventEmitter
  self = @

  constructor: (options, @robot) ->
    self = @

    unless options.token? and options.channels? and options.host?
      @robot.logger.error "Not enough parameters provided. I need a host, token, and channels."
      process.exit(1)

    @host     = options.host
    @port     = options.port
    @token    = options.token
    @channels = options.channels.split(",")

    target = "http://#{ @host }:#{ @port }/remote/faye"
    console.log("Connecting to #{ target }")

    @client = new Faye.Client(target)
    @client.disable('websocket')
    authExtension = {
      outgoing: (message, callback) =>
        if message.channel == "/meta/subscribe"
          message['ext'] = { auth_token: @token }
        callback(message)
    }
    @client.addExtension(authExtension)

    @client.bind "transport:down", () ->
      console.log "Connected to Faye server"

    @client.bind "transport:up", () ->
      console.log "Disconnected from Faye server"

    for channel in @channels
      subscription = @client.subscribe "/channels/#{channel}", (activity) =>
        eventMap =
          'enter':   'EnterMessage'
          'leave':   'LeaveMessage'
          'message': 'TextMessage'
        self.emit eventMap[activity.action], activity
      subscription.errback((activity) ->
        console.log "Error", activity
        console.log "Oops! could not connect to the server"
      )
    @

  message: (message, channelId, callback) ->
    body = {"content":message, "channel_id":channelId, "activity": {"content":message, "channel_id":channelId, "action":"message"}}
    @post "/channels/#{ channelId }/activities", body, callback

  Channels: (callback) ->
    @get "/channels", callback

  # Needs to be implemented in Kandan
  User: (id, callback) ->
    @get "/active_users.json", callback

  Me: (callback) ->
    @get "/me", callback

  Channel: (id) ->
    self = @
    logger = @robot.logger

    show: (callback) ->
      self.post "/channels/#{id}", "", callback

    join: (callback) ->
      @robot.logger.info "Join is a NOOP on Kandan right now"

    leave: (callback) ->
      @robot.logger.info "Leave is a NOOP on Kandan right now"


  get: (path, callback) ->
    @request "GET", path, null, callback

  post: (path, body, callback) ->
    @request "POST", path, body, callback

  request: (method, path, body, callback) ->
    logger = @robot.logger

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

          try
            callback null, JSON.parse(data) if callback?
          catch err
            callback null, data or { } if callback?

    if method is "POST" || method is "PUT"
      request.end(body, 'binary')
    else
      request.end()

    request.on "error", (err) ->
      logger.error "Kandan request error: #{err}"
