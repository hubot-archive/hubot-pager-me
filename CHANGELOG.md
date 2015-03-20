2.1.1
=====

* check for errors when making HTTP calls, and use hubot's error handling when they do happen

2.1.0
=====

* fix formatting of Nagios incidents
* add support for listing services and creating maintenance windows


2.0.4
=====

* fix `/pager incident` case-sensitivity

2.0.3
=====

* Update chat response to be less noisy if an incident isn't found
* Add support for restricting which services are displayed through an environment variable

2.0.2
=====

* Allow `/pager trigger` to work if user has configured PagerDuty email, but it doesn't match a PagerDuty user

2.0.1
=====

* Allow `/pager trigger` to work if user hasn't configured PagerDuty
* Fix exactly matching an escalation policy

2.0.0
=====

* Add support for multiple schedules
  * HUBOT_PAGERDUTY_SCHEDULE_ID is no longer used. Instead, the schedule name is given as part of the command
* Update `pager trigger` to be assigned to users, escalation policies, or schedules
* Add support for viewing schedules in a given timezone
* Update README with more example interactions

1.2.0
=====

* Update pager ack and pager resolve to only affect incidents assigned to you
* Add `pager ack!` and `pager resolve!` to preserve older behavior (ie ack and resolve all incidents)
* Add support for nooping interactions in development
* Improve `pager sup` when incident is assigned to multiple users


1.1.0
=====

* Add support for showing schedules and overrides, and creating overrides
* Improve error handling when user isn't found in PagerDuty

1.0.0
=====

* Extract from hubot-scripts repository and converted to script package
