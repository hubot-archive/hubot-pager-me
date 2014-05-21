# hubot-pager-me

PagerDuty integration for Hubot 

## Installation

In your hubot repository, run:

`npm install hubot-pager-me --save`

Then add **hubot-pager-me** to your `external-scripts.json`:

```json
["hubot-pager-me"]
```

## Configuration

`pager me` requires a bit of configuration to get everything working:

* HUBOT_PAGERDUTY_SUBDOMAIN - Your account subdomain
* HUBOT_PAGERDUTY_API_KEY - Get one from https://<your subdomain>.pagerduty.com/api_keys
* HUBOT_PAGERDUTY_SERVICE_API_KEY - Service API Key from a 'General API Service'
* HUBOT_PAGERDUTY_SCHEDULE_ID - The ID of the On-Call schedule used by `who's on call` and `pager me <minutes>`

### Shotgun


* HUBOT_PAGERDUTY_SHOTGUN_ID - a second ride-along schedule to the primary

### Webhook

Using a webhook requires a bit more configuration:

* HUBOT_PAGERDUTY_ENDPOINT - Pagerduty Webhook listener e.g /hook
* HUBOT_PAGERDUTY_ROOM - Room in which you want the pagerduty webhook notifications to appear

To setup the webhooks and get the alerts in your chatrooms, you need to add the endpoint you define here (e.g /hooks) in 
the service settings of your Pagerduty accounts. You also need to define the room in which you want them to appear. 
(Unless you want to spam all the rooms with alerts, but we don't believe that should be the default behavior :)  

## Resources

* http://developer.pagerduty.com/documentation/rest/webhooks
* http://support.pagerduty.com/entries/21774694-Webhooks-
