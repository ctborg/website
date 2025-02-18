mongoose = require 'mongoose'
ObjectId = mongoose.Schema.ObjectId

DeploySchema = module.exports = new mongoose.Schema
  teamId:
    type: ObjectId
    index: true
    required: true
  hostname: String
  os: String
  remoteAddress: String
  platform: String

# associations
DeploySchema.method 'team', (callback) ->
  Team = mongoose.model 'Team'
  Team.findById @teamId, callback

# validations
DeploySchema.path('remoteAddress').validate (v) ->
  @platform =
    if inNetwork v, '127.0.0.1/24'
      'localdomain'
    else if inNetwork v, '72.2.126.0/23'
      'joyent'
    else if inNetwork v, """
                         50.18.0.0/16     184.72.0.0/18   204.236.128.0/18
                         107.20.0.0/15    50.19.0.0/16    50.16.0.0/15
                         184.72.64.0/18   184.72.128.0/17 184.73.0.0/16
                         204.236.192.0/18 174.129.0.0/16  75.101.128.0/17
                         67.202.0.0/18    72.44.32.0/19   216.182.224.0/20
                         """
      'heroku'
    else if inNetwork v, '96.126.12.0/24', '74.207.251.0/24'
      'linode'
    else if v.match(/\.nodejitsu\.com$/)
      'nodejitsu'
  @platform?
, 'not production'

# callbacks
DeploySchema.post 'save', ->
  @team (err, team) =>
    throw err if err
    team.lastDeploy = @toObject()
    team.save()

Deploy = mongoose.model 'Deploy', DeploySchema

toBytes = (ip) ->
  [ a, b, c, d ] = ip.split '.'
  (a << 24 | b << 16 | c << 8 | d)

inNetwork = (ip, networks) ->
  for network in networks.split(/\s+/)
    [ network, netmask ] = network.split '/'
    netmask = 0x100000000 - (1 << 32 - netmask)
    return true if (toBytes(ip) & netmask) == (toBytes(network) & netmask)
  false
