# hubot-pager-me

[![npm version](https://badge.fury.io/js/hubot-pager-me.svg)](http://badge.fury.io/js/hubot-pager-me) [![Build Status](https://travis-ci.org/hubot-scripts/hubot-pager-me.svg?branch=master)](https://travis-ci.org/hubot-scripts/hubot-pager-me)

PagerDuty integration for Hubot.


## Installation

In your hubot repository, run:

`npm install hubot-pager-me --save`

Then add **hubot-pager-me** to your `external-scripts.json`:

```json
["hubot-pager-me"]
```

## Configuration

> **Upgrading from v2.x?** The `HUBOT_PAGERDUTY_SUBDOMAIN` parameter has been replaced with `HUBOT_PAGERDUTY_FROM_EMAIL`, which is [sent along as a header](https://v2.developer.pagerduty.com/docs/rest-api#http-request-headers) to indicate the actor for the incident creation workflow. This would be the email address for a bot user in PagerDuty.

| Environment Variable | Required? | Description                               |
| -------------------- | --------- | ----------------------------------------- |
| `HUBOT_PAGERDUTY_API_KEY` | Yes | The [REST API Key](https://support.pagerduty.com/docs/using-the-api#section-generating-an-api-key) for this integration.
| `HUBOT_PAGERDUTY_FROM_EMAIL` | Yes | The email of the default "actor" user for incident creation and modification. |
| `HUBOT_PAGERDUTY_USER_ID`  | No`*`` | The user ID of a PagerDuty user for your bot. This is only required if you want chat users to be able to trigger incidents without their own PagerDuty user.
| `HUBOT_PAGERDUTY_SERVICE_API_KEY` | No`*`` | The [Incident Service Key](https://v2.developer.pagerduty.com/docs/incident-creation-api) to use when creating a new incident. This should be assigned to a dummy escalation policy that doesn't actually notify, as Hubot will trigger on this before reassigning it.
| `HUBOT_PAGERDUTY_SERVICES` | No | Provide a comma separated list of service identifiers (e.g. `PFGPBFY,AFBCGH`) to restrict queries to only those services. |

`*` - May be required for certain actions.

### Webhook

| Environment Variable | Required? | Description                               |
| -------------------- | --------- | ----------------------------------------- |
| `HUBOT_PAGERDUTY_ENDPOINT` | Yes | PagerDuty webhook listener on your Hubot's server. Must be public. Example: `/hook`. |
| `HUBOT_PAGERDUTY_ROOM` | Yes | Room in which you want the pagerduty webhook notifications to appear. Example: `#pagerduty` |

To setup the webhooks and get the alerts in your chatrooms, you need to add the endpoint you define here (e.g `/hooks`) in
the service settings of your PagerDuty accounts. You also need to define the room in which you want them to appear. That is, unless you want to spam all the rooms with alerts, but we don't believe that should be the default behavior. 😁

## Example interactions

Trigger an incident assigned to a specific user:

```
technicalpickles> hubot pager trigger jnewland omgwtfbbq
hubot> technicalpickles: :pager: triggered! now assigning it to the right user...
hubot> technicalpickles: :pager: assigned to jnewland!
```

Trigger an incident assigned to an escalation policy:

```
technicalpickles> hubot pager trigger ops site is down
hubot> Shell: :pager: triggered! now assigning it to the right user...
hubot> Shell: :pager: assigned to ops!
```

Check on open incidents:

```
technicalpickles> hubot pager sup
hubot>
      Triggered:
      ----------
      8: 2014-11-05T20:17:50Z site is down - @technicalpickles - assigned to jnewland

      Acknowledged:
      -------------
      7: 2014-11-05T20:16:29Z omgwtfbbq - @technicalpickles - assigned to jnewland
```

Acknowledge triggered alerts assigned to you:

```
jnewland> /pager ack
hubot> jnewland: Incident 9 acknowledged
```

Resolve acknowledged alerts assigned to you:

```
jnewland> /pager resolve
hubot> jnewland: Incident 9 resolved
```

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

## Conventions

`hubot-pager-me` makes some assumptions about how you are using PagerDuty:

* PagerDuty email matches chat email
  * override with `hubot pager me as <pagerduty email>`
* The Service used by hubot-pager-me should not be assigned to an escalation policy with real people on it. Instead, it should be a dummy user that doesn't have any notification rules. If this isn't done, the escalation policy assigned to it will be notified, and then Hubot will immediately reassign to the proper team

## Development

Fork this repository, and clone it locally. To start using with an existing Hubot for testing:

* Run `npm install` in `hubot-pager-me` repository
* Run `npm link` in `hubot-pager-me` repository
* Run `npm link hubot-pager-me` in your Hubot directory
* NOTE: if you are using something like [nodenv](https://github.com/wfarr/nodenv) or similar, make sure your `npm link` from the same node version

There's a few environment variables useful for testing:

* `HUBOT_PAGERDUTY_NOOP`: Don't actually make POST/PUT HTTP requests.
* `HUBOT_PAGERDUTY_TEST_EMAIL`: Force email of address to this for testing.

## Resources

* https://v2.developer.pagerduty.com/docs/getting-started
* https://v2.developer.pagerduty.com/docs/webhooks-v2-overview
