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

### Webhook

Using a webhook requires a bit more configuration:

* HUBOT_PAGERDUTY_ENDPOINT - Pagerduty Webhook listener e.g /hook
* HUBOT_PAGERDUTY_ROOM - Room in which you want the pagerduty webhook notifications to appear

To setup the webhooks and get the alerts in your chatrooms, you need to add the endpoint you define here (e.g /hooks) in
the service settings of your Pagerduty accounts. You also need to define the room in which you want them to appear.
(Unless you want to spam all the rooms with alerts, but we don't believe that should be the default behavior :)  

## Example interactions

Check up coming schedule, and schedule shift overrides on it:

```
technicalpickles> hubot pager schedules
hubot> * Ops - https://urcompany.pagerduty.com/schedules#DEADBEE
technicalpickles> hubot pager schedule ops
hubot> * 2014-06-24T09:06:45-07:00 - 2014-06-25T03:00:00-07:00 technicalpickles
       * 2014-06-25T03:00:00-07:00 - 2014-06-26T03:00:00-07:00 jnewland
       * 2014-06-26T03:00:00-07:00 - 2014-06-27T03:00:00-07:00 technicalpickles
       * 2014-06-27T03:00:00-07:00 - 2014-06-28T03:00:00-07:00 jnewland
       * 2014-06-28T03:00:00-07:00 - 2014-06-29T03:00:00-07:00 technicalpickles
technicalpickles> hubot pager override ops 2014-06-25T03:00:00-07:00 - 2014-06-26T03:00:00-07:00 chrislundquist
hubot> Override setup! chrislundquist has the pager from 2014-06-25T06:00:00-04:00 until 2014-06-26T06:00:00-04:00
technicalpickles> hubot pager schedule
hubot> * 2014-06-24T09:06:45-07:00 - 2014-06-25T03:00:00-07:00 technicalpickles
       * 2014-06-25T03:00:00-07:00 - 2014-06-26T03:00:00-07:00 chrislundquist
       * 2014-06-26T03:00:00-07:00 - 2014-06-27T03:00:00-07:00 technicalpickles
       * 2014-06-27T03:00:00-07:00 - 2014-06-28T03:00:00-07:00 jnewland
       * 2014-06-28T03:00:00-07:00 - 2014-06-29T03:00:00-07:00 technicalpickles
```

## Development

Fork this repository, and clone it locally. To start using with an existing hubot for testing:

* Run `npm install` in hubot-pager-me repository
* Run `npm link` in hubot-pager-me repository
* Run `npm link hubot-pager-me` in your hubot directory
* NOTE: if you are using something like [nodenv](https://github.com/wfarr/nodenv) or similar, make sure your `npm link` from the same node version

There's a few environment variables useful for testing:

* HUBOT_PAGERDUTY_NOOP: don't actually make POST/PUT HTTP requests
* HUBOT_PAGERDUTY_TEST_EMAIL: force email of address to this for testing

## Resources

* http://developer.pagerduty.com/documentation/rest/webhooks
* http://support.pagerduty.com/entries/21774694-Webhooks-
