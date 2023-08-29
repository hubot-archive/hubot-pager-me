// Description:
//   Receive webhooks from PagerDuty and post them to chat
//

const pagerRoom = process.env.HUBOT_PAGERDUTY_ROOM;
// Webhook listener endpoint. Set it to whatever URL you want, and make sure it matches your pagerduty service settings
const pagerEndpoint = process.env.HUBOT_PAGERDUTY_ENDPOINT || '/hook';

module.exports = function (robot) {
  // Webhook listener
  let generateIncidentString;
  if (pagerEndpoint && pagerRoom) {
    robot.router.post(pagerEndpoint, function (req, res) {
      robot.messageRoom(pagerRoom, parseWebhook(req, res));
      return res.end();
    });
  }

  // Pagerduty Webhook Integration (For a payload example, see http://developer.pagerduty.com/documentation/rest/webhooks)
  var parseWebhook = function (req, res) {
    const hook = req.body;

    const { messages } = hook;

    if (/^incident.*$/.test(messages[0].type)) {
      return parseIncidents(messages);
    } else {
      return 'No incidents in webhook';
    }
  };

  var parseIncidents = function (messages) {
    const returnMessage = [];
    let count = 0;
    for (var message of Array.from(messages)) {
      var { incident } = message.data;
      var hookType = message.type;
      returnMessage.push(generateIncidentString(incident, hookType));
      count = count + 1;
    }
    returnMessage.unshift('You have ' + count + ' PagerDuty update(s): \n');
    return returnMessage.join('\n');
  };

  const getUserForIncident = function (incident) {
    if (incident.assigned_to_user) {
      return incident.assigned_to_user.email;
    } else if (incident.resolved_by_user) {
      return incident.resolved_by_user.email;
    } else {
      return '(???)';
    }
  };

  return (generateIncidentString = function (incident, hookType) {
    console.log('hookType is ' + hookType);
    const assigned_user = getUserForIncident(incident);
    const { incident_number } = incident;

    if (hookType === 'incident.trigger') {
      return `\
Incident # ${incident_number} :
${incident.status} and assigned to ${assigned_user}
 ${incident.html_url}
To acknowledge: @${robot.name} pager me ack ${incident_number}
To resolve: @${robot.name} pager me resolve \
`;
    } else if (hookType === 'incident.acknowledge') {
      return `\
Incident # ${incident_number} :
${incident.status} and assigned to ${assigned_user}
 ${incident.html_url}
To resolve: @${robot.name} pager me resolve ${incident_number}\
`;
    } else if (hookType === 'incident.resolve') {
      return `\
Incident # ${incident_number} has been resolved by ${assigned_user}
 ${incident.html_url}\
`;
    } else if (hookType === 'incident.unacknowledge') {
      return `\
${incident.status} , unacknowledged and assigned to ${assigned_user}
 ${incident.html_url}
To acknowledge: @${robot.name} pager me ack ${incident_number}
 To resolve: @${robot.name} pager me resolve ${incident_number}\
`;
    } else if (hookType === 'incident.assign') {
      return `\
Incident # ${incident_number} :
${incident.status} , reassigned to ${assigned_user}
 ${incident.html_url}
To resolve: @${robot.name} pager me resolve ${incident_number}\
`;
    } else if (hookType === 'incident.escalate') {
      return `\
Incident # ${incident_number} :
${incident.status} , was escalated and assigned to ${assigned_user}
 ${incident.html_url}
To acknowledge: @${robot.name} pager me ack ${incident_number}
To resolve: @${robot.name} pager me resolve ${incident_number}\
`;
    }
  });
};
