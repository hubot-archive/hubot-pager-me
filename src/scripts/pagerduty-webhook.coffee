# Description:
#   Receive webhooks from PagerDuty and post them to chat
#

pagerRoom              = process.env.HUBOT_PAGERDUTY_ROOM
# Webhook listener endpoint. Set it to whatever URL you want, and make sure it matches your pagerduty service settings
pagerEndpoint          = process.env.HUBOT_PAGERDUTY_ENDPOINT || "/hook"

module.exports = (robot) ->
  # Webhook listener
  if pagerEndpoint && pagerRoom
    robot.router.post pagerEndpoint, (req, res) ->
      robot.messageRoom(pagerRoom, parseWebhook(req,res))
      res.end()

  # Pagerduty Webhook Integration (For a payload example, see http://developer.pagerduty.com/documentation/rest/webhooks)
  parseWebhook = (req, res) ->
    hook = req.body

    messages = hook.messages

    if /^incident.*$/.test(messages[0].type)
      parseIncidents(messages)
    else
      "No incidents in webhook"

  parseIncidents = (messages) ->
    returnMessage = []
    count = 0
    for message in messages
      incident = message.data.incident
      hookType = message.type
      returnMessage.push(generateIncidentString(incident, hookType))
      count = count+1
    returnMessage.unshift("You have " + count + " PagerDuty update(s): \n")
    returnMessage.join("\n")

  getUserForIncident = (incident) ->
    if incident.assigned_to_user
      incident.assigned_to_user.email
    else if incident.resolved_by_user
      incident.resolved_by_user.email
    else
      '(???)'

  generateIncidentString = (incident, hookType) ->
    console.log "hookType is " + hookType
    assigned_user   = getUserForIncident(incident)
    incident_number = incident.incident_number

    if hookType == "incident.trigger"
      """
      Incident # #{incident_number} :
      #{incident.status} and assigned to #{assigned_user}
       #{incident.html_url}
      To acknowledge: @#{robot.name} pager me ack #{incident_number}
      To resolve: @#{robot.name} pager me resolve #{}
      """
    else if hookType == "incident.acknowledge"
      """
      Incident # #{incident_number} :
      #{incident.status} and assigned to #{assigned_user}
       #{incident.html_url}
      To resolve: @#{robot.name} pager me resolve #{incident_number}
      """
    else if hookType == "incident.resolve"
      """
      Incident # #{incident_number} has been resolved by #{assigned_user}
       #{incident.html_url}
      """
    else if hookType == "incident.unacknowledge"
      """
      #{incident.status} , unacknowledged and assigned to #{assigned_user}
       #{incident.html_url}
      To acknowledge: @#{robot.name} pager me ack #{incident_number}
       To resolve: @#{robot.name} pager me resolve #{incident_number}
      """
    else if hookType == "incident.assign"
      """
      Incident # #{incident_number} :
      #{incident.status} , reassigned to #{assigned_user}
       #{incident.html_url}
      To resolve: @#{robot.name} pager me resolve #{incident_number}
      """
    else if hookType == "incident.escalate"
      """
      Incident # #{incident_number} :
      #{incident.status} , was escalated and assigned to #{assigned_user}
       #{incident.html_url}
      To acknowledge: @#{robot.name} pager me ack #{incident_number}
      To resolve: @#{robot.name} pager me resolve #{incident_number}
      """
