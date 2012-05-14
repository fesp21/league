# Published collections
Meteor.publish 'teams', -> Teams.find()

Meteor.publish 'players', (team_id) -> 
  console.log "getting players for #{team_id}"
  Players.find({team_id: team_id})
Meteor.publish 'games', (team_id) -> Games.find({team_id: team_id})

# Published methods
Meteor.methods
  'login': (facebook_id) ->
    console.log "logging in user with FB ID: #{facebook_id}"
    Players.findOne({facebook_id: facebook_id})
  'logout': -> 
    console.log "logging out user with FB ID: #{facebook_id}"
    # do nothing for now