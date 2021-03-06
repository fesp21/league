# this is a Facebook authentication system. With more thought it could be generalised
# and the FB system could be a subclass... thoughts for another day
#
# Uses two session variables, current_user_id and login_status
#  TODO -- use a local var and set it up to trigger external things via deps
#
# There are 4 states we can be in, with different ways to get there:
# 1. 'loggin_in' (fb: N/A)
#   -- we are still waiting on FB to tell us what the deal is. Reachable:
#   A. when we first load
# 2. 'logged_out', (fb: 'unknown')
#   -- we aren't logged into a fb account. Can be reached via:
#   A. when FB first reports (need to call getLoginStatus to detect it, seems like a FB bug)
#   B. after they click the logout button
# 3. 'not_authorized', (fb: 'not_authorized). Treated more or less like 2.
#   -- we've logged in, but the app is not yet authorized. Reachable:
#   A. when FB first reports
#   [B.] if they open the login dialog from 2. but only get halfway (i.e login but not auth.)
#       -- we don't hear about this. But it's OK, we don't really care.
# 4. 'logged_in', (fb: 'connected')
#   -- all is good, we are logged in, both with FB and with the app. Reachable
#   A. When FB first reports
#   B. When the login dialog is successful.

Session.set('fbauthsystem.login_status', 'logging_in')

class FBAuthSystem
  init: ->
    # initialize our connection to FB.
    Facebook.load =>
      FB.init 
        appId: Facebook.appId
        channelUrl: Facebook.channelUrl
      
      # we need to call this as FB for some reason doesn't tell us if we aren't initially
      # logged out (and so we end up waiting forever for confirmation)
      FB.getLoginStatus (response) =>
        @_handleLogout() if response.status == 'unknown'
      
      # this subscription handles all types of status changes apart from #2A
      FB.Event.subscribe 'auth.statusChange', (r) => 
        if r.status == 'connected'
          @_handleLogin(r.authResponse)
        else if r.status == 'not_authorized'
          @_handleNotAuthorized()
        else
          @_handleLogout()
      
  
  @login_states = ['logging_in', 'logged_in', 'logged_out', 'not_authorized']
  login_status: -> Session.get('fbauthsystem.login_status')
  for state in @login_states
    # need to be slightly OTT here to bind the state variable properly (is there a cleaner way to do this?)
    this.prototype[state] = ((s) -> 
      -> Session.equals('fbauthsystem.login_status', s)
    )(state)
  
  # initiate login process (if it hasn't already happened).
  force_login: (login_callback, logout_callback) ->
    return (login_callback() if login_callback) if @logged_in() # they are logged in already
    
    # we haven't yet initialized facebook, so we need to just set the callback while we wait
    @login_callback = login_callback if login_callback
    @logout_callback = logout_callback if logout_callback
    
    # they aren't logged in, so we'll ask facebook to try, assuming it's ready
    #   we can only do this right away (we can't open a dialog without user input)
    #   so either do it now, or never
    return FB.login null,  {scope: 'email'} if FB?
  
  # more relaxed -- do one thing if we are logged in, another if we are not, 
  #   waiting for FB to return
  if_logged_in: (login_callback, logout_callback) ->
    if FB?
      if @logged_in()
        login_callback() if login_callback
      else
        logout_callback() if logout_callback
    
    else # wait for it to happen
      @login_callback = login_callback if login_callback
      @logout_callback = logout_callback if logout_callback
  
  force_logout: -> 
    FB.logout() if @logged_in()
  
  _login_callback: ->
    @login_callback() if @login_callback
    @login_callback = null
  
  _logout_callback: ->
    @logout_callback() if @logout_callback
    @logout_callback = null

  _handleLogin: (authResponse) ->
    Meteor.call 'login', authResponse.userID, (error, user) => 
      console.log user
      @_doLogin(user) if user # the user already exists
      
      return if user and user.attributes.email
      # else, better get some deets from the FB
      FB.api '/me', (me) => 
        attributes = { name: me.name, facebook_id: me.id, email: me.email }
        Meteor.call 'create_or_update', attributes, (error, user) =>
          @_doLogin(user) unless @logged_in()
  
  _doLogin: (user) ->
    console.log("logging in #{user.id}")
    Session.set('fbauthsystem.login_status', 'logged_in')
    Session.set('current_user_id', user.id)
    @_login_callback()
    
  _handleLogout: -> 
    Session.set 'current_user_id', null
    Session.set 'fbauthsystem.login_status', 'logged_out'
    @_logout_callback()
  
  _handleNotAuthorized: ->
    Session.set 'current_user_id', null
    Session.set 'fbauthsystem.login_status', 'not_authorized'
    @_logout_callback()
  
# prepare a singleton instance
AuthSystem = new FBAuthSystem
Meteor.startup -> AuthSystem.init()