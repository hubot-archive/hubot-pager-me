// Description:
//   Interact with PagerDuty services, schedules, and incidents with Hubot.
//
// Commands:
//   hubot pager me as <email> - remember your pager email is <email>
//   hubot pager forget me - forget your pager email
//   hubot am I on call - return if I'm currently on call or not
//   hubot who's on call - return a list of services and who is on call for them
//   hubot who's on call for <schedule> - return the username of who's on call for any schedule matching <search>
//   hubot pager trigger <user> <msg> - create a new incident with <msg> and assign it to <user>
//   hubot pager trigger <schedule> <msg> - create a new incident with <msg> and assign it the user currently on call for <schedule>
//   hubot pager incidents - return the current incidents
//   hubot pager sup - return the current incidents
//   hubot pager incident <incident> - return the incident NNN
//   hubot pager note <incident> <content> - add note to incident #<incident> with <content>
//   hubot pager notes <incident> - show notes for incident #<incident>
//   hubot pager problems - return all open incidents
//   hubot pager ack <incident> - ack incident #<incident>
//   hubot pager ack - ack triggered incidents assigned to you
//   hubot pager ack! - ack all triggered incidents, not just yours
//   hubot pager ack <incident1> <incident2> ... <incidentN> - ack all specified incidents
//   hubot pager resolve <incident> - resolve incident #<incident>
//   hubot pager resolve <incident1> <incident2> ... <incidentN> - resolve all specified incidents
//   hubot pager resolve - resolve acknowledged incidents assigned to you
//   hubot pager resolve! - resolve all acknowledged, not just yours
//   hubot pager schedules - list schedules
//   hubot pager schedules <search> - list schedules matching <search>
//   hubot pager schedule <schedule> [days] - show <schedule>'s shifts for the next x [days] (default 30 days)
//   hubot pager my schedule <days> - show my on call shifts for the upcoming <days> in all schedules (default 30 days)
//   hubot pager me <schedule> <minutes> - take the pager for <minutes> minutes
//   hubot pager override <schedule> <start> - <end> [username] - Create an schedule override from <start> until <end>. If [username] is left off, defaults to you. start and end should date-parsable dates, like 2014-06-24T09:06:45-07:00, see http://momentjs.com/docs/#/parsing/string/ for examples.
//   hubot pager overrides <schedule> [days] - show upcoming overrides for the next x [days] (default 30 days)
//   hubot pager override <schedule> delete <id> - delete an override by its ID
//   hubot pager services - list services
//   hubot pager maintenance <minutes> <service_id1> <service_id2> ... <service_idN> - schedule a maintenance window for <minutes> for specified services
//
// Authors:
//   Jesse Newland, Josh Nicols, Jacob Bednarz, Chris Lundquist, Chris Streeter, Joseph Pierri, Greg Hoin, Michael Warkentin

const pagerduty = require('../pagerduty');
const async = require('async');
const { inspect } = require('util');
const moment = require('moment-timezone');

const pagerDutyUserId = process.env.HUBOT_PAGERDUTY_USER_ID;
const pagerDutyServiceApiKey = process.env.HUBOT_PAGERDUTY_SERVICE_API_KEY;
const pagerDutySchedules = process.env.HUBOT_PAGERDUTY_SCHEDULES;
const pagerDutyDefaultSchedule = process.env.HUBOT_PAGERDUTY_DEFAULT_SCHEDULE;

module.exports = function (robot) {
  let campfireUserToPagerDutyUser;

  robot.respond(/pager( me)?$/i, function (msg) {
    if (pagerduty.missingEnvironmentForApi(msg)) {
      return;
    }

    campfireUserToPagerDutyUser(msg, msg.message.user, function (user) {
      const emailNote = (() => {
        if (msg.message.user.pagerdutyEmail) {
          return `You've told me your PagerDuty email is ${msg.message.user.pagerdutyEmail}`;
        } else if (msg.message.user.email_address) {
          return `I'm assuming your PagerDuty email is ${msg.message.user.email_address}. Change it with \`${robot.name} pager me as you@yourdomain.com\``;
        }
      })();
      if (user) {
        msg.send(`I found your PagerDuty user ${user.html_url}, ${emailNote}`);
      } else {
        msg.send(`I couldn't find your user :( ${emailNote}`);
      }
    });

    let cmds = robot.helpCommands();
    cmds = (() => {
      const result = [];
      for (var cmd of Array.from(cmds)) {
        if (cmd.match(/hubot (pager |who's on call)/)) {
          result.push(cmd);
        }
      }
      return result;
    })();
    msg.send(cmds.join('\n'));
  });

  robot.respond(/pager(?: me)? as (.*)$/i, function (msg) {
    const email = msg.match[1];
    msg.message.user.pagerdutyEmail = email;
    msg.send(`Okay, I'll remember your PagerDuty email is ${email}`);
  });

  robot.respond(/pager forget me$/i, function (msg) {
    msg.message.user.pagerdutyEmail = undefined;
    msg.send("Okay, I've forgotten your PagerDuty email");
  });

  robot.respond(/(pager|major)( me)? incident ([a-z0-9]+)$/i, function (msg) {
    msg.finish();

    if (pagerduty.missingEnvironmentForApi(msg)) {
      return;
    }

    return pagerduty.getIncident(msg.match[3], function (err, incident) {
      if (err != null) {
        robot.emit('error', err, msg);
        return;
      }

      if (!incident || !incident['incident']) {
        logger.debug(incident);
        msg.send('No matching incident found for `msg.match[3]`.');
        return;
      }

      msg.send(formatIncident(incident['incident']));
    });
  });

  robot.respond(/(pager|major)( me)? (inc|incidents|sup|problems)$/i, (msg) =>
    pagerduty.getIncidents('triggered,acknowledged', function (err, incidents) {
      if (err != null) {
        robot.emit('error', err, msg);
        return;
      }

      if (incidents.length == 0) {
        msg.send('No open incidents');
        return;
      }

      let incident, junk;
      let buffer = 'Triggered:\n----------\n';
      const object = incidents.reverse();
      for (junk in object) {
        incident = object[junk];
        if (incident.status === 'triggered') {
          buffer = buffer + formatIncident(incident);
        }
      }
      buffer = buffer + '\nAcknowledged:\n-------------\n';
      const object1 = incidents.reverse();
      for (junk in object1) {
        incident = object1[junk];
        if (incident.status === 'acknowledged') {
          buffer = buffer + formatIncident(incident);
        }
      }
      msg.send(buffer);
    })
  );

  robot.respond(/(pager|major)( me)? (?:trigger|page) ([\w\-]+)$/i, (msg) =>
    msg.reply("Please include a user or schedule to page, like 'hubot pager infrastructure everything is on fire'.")
  );

  robot.respond(
    /(pager|major)( me)? (?:trigger|page) ?((["'])([^\4]*?)\4|“([^”]*?)”|‘([^’]*?)’|([\.\w\-]+))? ?(.+)?$/i,
    function (msg) {
      msg.finish();

      if (pagerduty.missingEnvironmentForApi(msg)) {
        return;
      }
      const fromUserName = msg.message.user.name;
      let query, description;
      if (!msg.match[4] && !msg.match[5] && !msg.match[6] && !msg.match[7] && !msg.match[8] && !msg.match[9]) {
        robot.logger.info(`Triggering a default page to ${pagerDutyDefaultSchedule}!`);
        if (!pagerDutyDefaultSchedule) {
          msg.send("No default schedule configured! Cannot send a page! Please set HUBOT_PAGERDUTY_DEFAULT_SCHEDULE");
          return;
        }
        query = pagerDutyDefaultSchedule;
        description = `Generic Page - @${fromUserName}`;
      } else {
        query = msg.match[5] || msg.match[6] || msg.match[7] || msg.match[8];
        robot.logger.info(`Triggering a page to ${query}!`);
        const reason = msg.match[9];
        description = `${reason} - @${fromUserName}`;
      }

      // Figure out who we are
      campfireUserToPagerDutyUser(msg, msg.message.user, false, function (triggerdByPagerDutyUser) {
        const triggerdByPagerDutyUserId = (() => {
          if (triggerdByPagerDutyUser != null) {
            return triggerdByPagerDutyUser.id;
          } else if (pagerDutyUserId) {
            return pagerDutyUserId;
          }
        })();
        if (!triggerdByPagerDutyUserId) {
          msg.send(
            `Sorry, I can't figure your PagerDuty account, and I don't have my own :( Can you tell me your PagerDuty email with \`${robot.name} pager me as you@yourdomain.com\` or make sure you've set the HUBOT_PAGERDUTY_USER_ID environment variable?`
          );
          return;
        }

        // Figure out what we're trying to page
        reassignmentParametersForUserOrScheduleOrEscalationPolicy(msg, query, function (results) {
          if (!(results.assigned_to_user || results.escalation_policy)) {
            msg.reply(`Couldn't find a user or unique schedule or escalation policy matching ${query} :/`);
            return;
          }

          return pagerDutyIntegrationAPI(msg, 'trigger', description, function (json) {
            query = { incident_key: json.incident_key };

            msg.reply(':pager: triggered! now assigning it to the right user...');

            return setTimeout(
              () =>
                pagerduty.get('/incidents', query, function (err, json) {
                  if (err != null) {
                    robot.emit('error', err, msg);
                    return;
                  }

                  if ((json != null ? json.incidents.length : undefined) === 0) {
                    msg.reply("Couldn't find the incident we just created to reassign. Please try again :/");
                  } else {
                  }

                  let data = null;
                  if (results.escalation_policy) {
                    data = {
                      incidents: json.incidents.map((incident) => ({
                        id: incident.id,
                        type: 'incident_reference',

                        escalation_policy: {
                          id: results.escalation_policy,
                          type: 'escalation_policy_reference',
                        },
                      })),
                    };
                  } else {
                    data = {
                      incidents: json.incidents.map((incident) => ({
                        id: incident.id,
                        type: 'incident_reference',

                        assignments: [
                          {
                            assignee: {
                              id: results.assigned_to_user,
                              type: 'user_reference',
                            },
                          },
                        ],
                      })),
                    };
                  }

                  return pagerduty.put('/incidents', data, function (err, json) {
                    if (err != null) {
                      robot.emit('error', err, msg);
                      return;
                    }

                    if ((json != null ? json.incidents.length : undefined) === 1) {
                      return msg.reply(`:pager: assigned to ${results.name}!`);
                    } else {
                      return msg.reply('Problem reassigning the incident :/');
                    }
                  });
                }),
              10000
            );
          });
        });
      });
    }
  );

  robot.respond(/(?:pager|major)(?: me)? ack(?:nowledge)? (.+)$/i, function (msg) {
    msg.finish();
    if (pagerduty.missingEnvironmentForApi(msg)) {
      return;
    }

    const incidentNumbers = parseIncidentNumbers(msg.match[1]);

    // only acknowledge triggered things, since it doesn't make sense to re-acknowledge if it's already in re-acknowledge
    // if it ever doesn't need acknowledge again, it means it's timed out and has become 'triggered' again anyways
    updateIncidents(msg, incidentNumbers, 'triggered,acknowledged', 'acknowledged');
  });

  robot.respond(/(pager|major)( me)? ack(nowledge)?(!)?$/i, function (msg) {
    if (pagerduty.missingEnvironmentForApi(msg)) {
      return;
    }

    const force = msg.match[4] != null;

    pagerduty.getIncidents('triggered,acknowledged', function (err, incidents) {
      if (err != null) {
        robot.emit('error', err, msg);
        return;
      }

      return campfireUserToPagerDutyUser(msg, msg.message.user, function (user) {
        const filteredIncidents = force
          ? incidents // don't filter at all
          : incidentsByUserId(incidents, user.id); // filter by id

        if (filteredIncidents.length === 0) {
          // nothing assigned to the user, but there were others
          if (incidents.length > 0 && !force) {
            msg.send(
              "Nothing assigned to you to acknowledge. Acknowledge someone else's incident with `hubot pager ack <nnn>`"
            );
          } else {
            msg.send('Nothing to acknowledge');
          }
          return;
        }

        const incidentNumbers = Array.from(filteredIncidents).map((incident) => incident.incident_number);

        // only acknowledge triggered things
        return updateIncidents(msg, incidentNumbers, 'triggered,acknowledged', 'acknowledged');
      });
    });
  });

  robot.respond(/(?:pager|major)(?: me)? res(?:olve)?(?:d)? (.+)$/i, function (msg) {
    msg.finish();

    if (pagerduty.missingEnvironmentForApi(msg)) {
      return;
    }

    const incidentNumbers = parseIncidentNumbers(msg.match[1]);

    // allow resolving of triggered and acknowedlge, since being explicit
    return updateIncidents(msg, incidentNumbers, 'triggered,acknowledged', 'resolved');
  });

  robot.respond(/(pager|major)( me)? res(olve)?(d)?(!)?$/i, function (msg) {
    if (pagerduty.missingEnvironmentForApi(msg)) {
      return;
    }

    const force = msg.match[5] != null;
    return pagerduty.getIncidents('acknowledged', function (err, incidents) {
      if (err != null) {
        robot.emit('error', err, msg);
        return;
      }

      return campfireUserToPagerDutyUser(msg, msg.message.user, function (user) {
        const filteredIncidents = force
          ? incidents // don't filter at all
          : incidentsByUserId(incidents, user.id); // filter by id
        if (filteredIncidents.length === 0) {
          // nothing assigned to the user, but there were others
          if (incidents.length > 0 && !force) {
            msg.send(
              "Nothing assigned to you to resolve. Resolve someone else's incident with `hubot pager ack <nnn>`"
            );
          } else {
            msg.send('Nothing to resolve');
          }
          return;
        }

        const incidentNumbers = Array.from(filteredIncidents).map((incident) => incident.incident_number);

        // only resolve things that are acknowledged
        return updateIncidents(msg, incidentNumbers, 'acknowledged', 'resolved');
      });
    });
  });

  robot.respond(/(pager|major)( me)? notes (.+)$/i, function (msg) {
    msg.finish();

    if (pagerduty.missingEnvironmentForApi(msg)) {
      return;
    }

    const incidentId = msg.match[3];
    pagerduty.get(`/incidents/${incidentId}/notes`, {}, function (err, json) {
      if (err != null) {
        robot.emit('error', err, msg);
        return;
      }

      let buffer = '';
      for (var note of Array.from(json.notes)) {
        buffer += `${note.created_at} ${note.user.summary}: ${note.content}\n`;
      }
      msg.send(buffer);
    });
  });

  robot.respond(/(pager|major)( me)? note ([\d\w]+) (.+)$/i, function (msg) {
    msg.finish();

    if (pagerduty.missingEnvironmentForApi(msg)) {
      return;
    }

    const incidentId = msg.match[3];
    const content = msg.match[4];

    campfireUserToPagerDutyUser(msg, msg.message.user, function (user) {
      const userId = user.id;
      if (!userId) {
        return;
      }

      const data = {
        note: {
          content,
        },
        requester_id: userId,
      };

      pagerduty.post(`/incidents/${incidentId}/notes`, data, function (err, json) {
        if (err != null) {
          robot.emit('error', err, msg);
          return;
        }

        if (json && json.note) {
          msg.send(`Got it! Note created: ${json.note.content}`);
        } else {
          msg.send("Sorry, I couldn't do it :(");
        }
      });
    });
  });

  robot.respond(/(pager|major)( me)? schedules( ((["'])([^]*?)\5|(.+)))?$/i, function (msg) {
    const query = {};
    const scheduleName = msg.match[6] || msg.match[7];
    if (scheduleName) {
      query['query'] = scheduleName;
    }

    if (pagerduty.missingEnvironmentForApi(msg)) {
      return;
    }

    pagerduty.getSchedules(query, function (err, schedules) {
      if (err != null) {
        robot.emit('error', err, msg);
        return;
      }

      if (schedules.length == 0) {
        msg.send('No schedules found!');
        return;
      }

      let buffer = '';
      for (var schedule of Array.from(schedules)) {
        buffer += `* ${schedule.name} - ${schedule.html_url}\n`;
      }
      msg.send(buffer);
    });
  });

  robot.respond(
    /(pager|major)( me)? (schedule|overrides)( ((["'])([^]*?)\6|([\w\-]+)))?( ([^ ]+)\s*(\d+)?)?$/i,
    function (msg) {
      let days, timezone;
      if (pagerduty.missingEnvironmentForApi(msg)) {
        return;
      }

      if (msg.match[11]) {
        days = msg.match[11];
      } else {
        days = 30;
      }

      const query = {
        since: moment().format(),
        until: moment().add(days, 'days').format(),
        overflow: 'true',
      };

      let thing = '';
      if (msg.match[3] && msg.match[3].match(/overrides/)) {
        thing = 'overrides';
        query['editable'] = 'true';
      }

      const scheduleName = msg.match[7] || msg.match[8];

      if (!scheduleName) {
        msg.reply(
          `Please specify a schedule with 'pager ${msg.match[3]} <name>.'' Use 'pager schedules' to list all schedules.`
        );
        return;
      }

      if (msg.match[10]) {
        timezone = msg.match[10];
      } else {
        timezone = 'UTC';
      }

      withScheduleMatching(msg, scheduleName, function (schedule) {
        const scheduleId = schedule.id;
        if (!scheduleId) {
          return;
        }

        pagerduty.get(`/schedules/${scheduleId}/${thing}`, query, function (err, json) {
          if (err != null) {
            robot.emit('error', err, msg);
            return;
          }

          const entries =
            __guard__(
              __guard__(json != null ? json.schedule : undefined, (x1) => x1.final_schedule),
              (x) => x.rendered_schedule_entries
            ) || json.overrides;
          if (entries) {
            const sortedEntries = entries.sort((a, b) => moment(a.start).unix() - moment(b.start).unix());

            let buffer = '';
            for (var entry of Array.from(sortedEntries)) {
              var startTime = moment(entry.start).tz(timezone).format();
              var endTime = moment(entry.end).tz(timezone).format();
              if (entry.id) {
                buffer += `* (${entry.id}) ${startTime} - ${endTime} ${entry.user.summary}\n`;
              } else {
                buffer += `* ${startTime} - ${endTime} ${entry.user.name}\n`;
              }
            }
            if (buffer === '') {
              msg.send('None found!');
            } else {
              msg.send(buffer);
            }
          } else {
            msg.send('None found!');
          }
        });
      });
    }
  );

  robot.respond(/(pager|major)( me)? my schedule( ([^ ]+)\s?(\d+))?$/i, function (msg) {
    let days;
    if (pagerduty.missingEnvironmentForApi(msg)) {
      return;
    }

    if (msg.match[5]) {
      days = msg.match[5];
    } else {
      days = 30;
    }

    campfireUserToPagerDutyUser(msg, msg.message.user, function (user) {
      let timezone;
      const userId = user.id;

      const query = {
        since: moment().format(),
        until: moment().add(days, 'days').format(),
        overflow: 'true',
      };

      if (msg.match[4]) {
        timezone = msg.match[4];
      } else {
        timezone = 'UTC';
      }

      pagerduty.getSchedules(function (err, schedules) {
        if (err != null) {
          robot.emit('error', err, msg);
          return;
        }

        if (schedules.length > 0) {
          const renderSchedule = (schedule, cb) =>
            pagerduty.get(`/schedules/${schedule.id}`, query, function (err, json) {
              if (err != null) {
                cb(err);
              }

              const entries = __guard__(
                __guard__(json != null ? json.schedule : undefined, (x1) => x1.final_schedule),
                (x) => x.rendered_schedule_entries
              );

              if (entries) {
                const sortedEntries = entries.sort((a, b) => moment(a.start).unix() - moment(b.start).unix());

                let buffer = '';
                for (var entry of Array.from(sortedEntries)) {
                  if (userId === entry.user.id) {
                    var startTime = moment(entry.start).tz(timezone).format();
                    var endTime = moment(entry.end).tz(timezone).format();

                    buffer += `* ${startTime} - ${endTime} ${entry.user.summary} (${schedule.name})\n`;
                  }
                }
                cb(null, buffer);
              }
            });

          return async.map(schedules, renderSchedule, function (err, results) {
            if (err != null) {
              robot.emit('error', err, msg);
              return;
            }
            msg.send(results.join(''));
          });
        } else {
          msg.send('No schedules found!');
        }
      });
    });
  });

  robot.respond(
    /(pager|major)( me)? (override) ((["'])([^]*?)\5|([\w\-]+)) ([\w\-:\+]+) - ([\w\-:\+]+)( (.*))?$/i,
    function (msg) {
      let overrideUser;
      if (pagerduty.missingEnvironmentForApi(msg)) {
        return;
      }

      const scheduleName = msg.match[6] || msg.match[7];

      if (msg.match[11]) {
        overrideUser = robot.brain.userForName(msg.match[11]);

        if (!overrideUser) {
          msg.send("Sorry, I don't seem to know who that is. Are you sure they are in chat?");
          return;
        }
      } else {
        overrideUser = msg.message.user;
      }

      campfireUserToPagerDutyUser(msg, overrideUser, function (user) {
        const userId = user.id;
        if (!userId) {
          return;
        }

        withScheduleMatching(msg, scheduleName, function (schedule) {
          const scheduleId = schedule.id;
          if (!scheduleId) {
            return;
          }

          if (moment(msg.match[8]).isValid() && moment(msg.match[9]).isValid()) {
            const start_time = moment(msg.match[8]).format();
            const end_time = moment(msg.match[9]).format();

            const override = {
              start: start_time,
              end: end_time,
              user: {
                id: userId,
                type: 'user_reference',
              },
            };
            const data = { override };
            return pagerduty.post(`/schedules/${scheduleId}/overrides`, data, function (err, json) {
              if (err != null) {
                robot.emit('error', err, msg);
                return;
              }

              if (json && json.override) {
                const start = moment(json.override.start);
                const end = moment(json.override.end);
                msg.send(
                  `Override setup! ${
                    json.override.user.summary
                  } has the pager from ${start.format()} until ${end.format()}`
                );
              } else {
                msg.send("That didn't work. Check Hubot's logs for an error!");
              }
            });
          } else {
            msg.send('Please use a http://momentjs.com/ compatible date!');
          }
        });
      });
    }
  );

  robot.respond(/(pager|major)( me)? (overrides?) ((["'])([^]*?)\5|([\w\-]+)) (delete) (.*)$/i, function (msg) {
    if (pagerduty.missingEnvironmentForApi(msg)) {
      return;
    }

    const scheduleName = msg.match[6] || msg.match[7];

    withScheduleMatching(msg, scheduleName, function (schedule) {
      const scheduleId = schedule.id;
      if (!scheduleId) {
        return;
      }

      pagerduty.delete(`/schedules/${scheduleId}/overrides/${msg.match[9]}`, function (err, success) {
        if (success) {
          msg.send(':boom:');
        } else {
          msg.send('Something went weird.');
        }
      });
    });
  });

  robot.respond(/pager( me)? (?!schedules?\b|overrides?\b|my schedule\b)(.+) (\d+)$/i, function (msg) {
    msg.finish();

    if (pagerduty.missingEnvironmentForApi(msg)) {
      return;
    }

    campfireUserToPagerDutyUser(msg, msg.message.user, function (user) {
      const userId = user.id;
      if (!userId) {
        return;
      }

      if (!msg.match[2] || msg.match[2] === 'me') {
        msg.reply(
          "Please specify a schedule with 'pager me infrastructure 60'. Use 'pager schedules' to list all schedules."
        );
        return;
      }
      const schedule = msg.match[2].replace(/(^"|"$)/mg, '');
      withScheduleMatching(msg, msg.match[2], function (matchingSchedule) {
        if (!matchingSchedule.id) {
          return;
        }

        let start = moment().format();
        const minutes = parseInt(msg.match[3]);
        let end = moment().add(minutes, 'minutes').format();
        const override = {
          start,
          end,
          user: {
            id: userId,
            type: 'user_reference',
          },
        };
        withCurrentOncall(msg, matchingSchedule, function (old_username, schedule) {
          const data = { override: override };
          return pagerduty.post(`/schedules/${schedule.id}/overrides`, data, function (err, json) {
            if (err != null) {
              robot.emit('error', err, msg);
              return;
            }

            if (json.override) {
              start = moment(json.override.start);
              end = moment(json.override.end);
              msg.send(
                `Rejoice, ${old_username}! ${json.override.user.summary} has the pager on ${
                  schedule.name
                } until ${end.format()}`
              );
            }
          });
        });
      });
    });
  });

  robot.respond(/am i on (call|oncall|on-call)/i, function (msg) {
    if (pagerduty.missingEnvironmentForApi(msg)) {
      return;
    }

    campfireUserToPagerDutyUser(msg, msg.message.user, function (user) {
      const userId = user.id;

      const renderSchedule = (s, cb) =>
        withCurrentOncallId(msg, s, function (oncallUserid, oncallUsername, schedule) {
          if (userId === oncallUserid) {
            cb(null, `* Yes, you are on call for ${schedule.name} - ${schedule.html_url}`);
          } else if (oncallUsername === null) {
            cb(null, `* No, you are NOT on call for ${schedule.name} - ${schedule.html_url}`);
          } else {
            cb(
              null,
              `* No, you are NOT on call for ${schedule.name} (but ${oncallUsername} is) - ${schedule.html_url}`
            );
          }
        });

      if (userId == null) {
        msg.send("Couldn't figure out the pagerduty user connected to your account.");
      } else {
        pagerduty.getSchedules(function (err, schedules) {
          if (err != null) {
            robot.emit('error', err, msg);
            return;
          }

          if (schedules.length == 0) {
            msg.send('No schedules found!');
          }

          async.map(schedules, renderSchedule, function (err, results) {
            if (err != null) {
              robot.emit('error', err, msg);
              return;
            }
            msg.send(results.join('\n'));
          });
        });
      }
    });
  });

  // who is on call?
  robot.respond(
    /who(?:’s|'s|s| is|se)? (?:on call|oncall|on-call)(?:\?)?(?: (?:for )?((["'])([^]*?)\2|(.*?))(?:\?|$))?$/i,
    function (msg) {
      if (pagerduty.missingEnvironmentForApi(msg)) {
        return;
      }

      const scheduleName = msg.match[3] || msg.match[4];

      const messages = [];
      let allowed_schedules = [];
      if (pagerDutySchedules != null) {
        allowed_schedules = pagerDutySchedules.split(',');
      }

      const renderSchedule = (s, cb) =>
        withCurrentOncall(msg, s, function (username, schedule) {
          // If there is an allowed schedules array, skip returned schedule not in it
          if (allowed_schedules.length && !Array.from(allowed_schedules).includes(schedule.id)) {
            robot.logger.debug(`Schedule ${schedule.id} (${schedule.name}) not in HUBOT_PAGERDUTY_SCHEDULES`);
            cb(null);
            return;
          }

          // Ignore schedule if no user assigned to it
          if (username) {
            messages.push(`* ${username} is on call for ${schedule.name} - ${schedule.html_url}`);
          } else {
            robot.logger.debug(`No user for schedule ${schedule.name}`);
          }

          // Return callback
          cb(null);
        });

      if (scheduleName != null) {
        SchedulesMatching(msg, scheduleName, (s) =>
          async.map(s, renderSchedule, function (err) {
            if (err != null) {
              robot.emit('error', err, msg);
              return;
            }
            msg.send(messages.join('\n'));
          })
        );
      } else {
        pagerduty.getSchedules(function (err, schedules) {
          if (err != null) {
            robot.emit('error', err, msg);
            return;
          }
          if (schedules.length == 0) {
            msg.send('No schedules found!');
            return;
          }

          async.map(schedules, renderSchedule, function (err) {
            if (err != null) {
              robot.emit('error', err, msg);
              return;
            }
            msg.send(messages.join('\n'));
          });
        });
      }
    }
  );

  robot.respond(/(pager|major)( me)? services$/i, function (msg) {
    if (pagerduty.missingEnvironmentForApi(msg)) {
      return;
    }

    return pagerduty.get('/services', {}, function (err, json) {
      if (err != null) {
        robot.emit('error', err, msg);
        return;
      }

      let buffer = '';
      const { services } = json;
      if (services.length == 0) {
        msg.send('No services found!');
        return;
      }

      for (var service of Array.from(services)) {
        buffer += `* ${service.id}: ${service.name} (${service.status}) - ${service.html_url}\n`;
      }
      msg.send(buffer);
    });
  });

  robot.respond(/(pager|major)( me)? maintenance (\d+) (.+)$/i, function (msg) {
    if (pagerduty.missingEnvironmentForApi(msg)) {
      return;
    }

    return campfireUserToPagerDutyUser(msg, msg.message.user, function (user) {
      const requester_id = user.id;
      if (!requester_id) {
        return;
      }

      const minutes = msg.match[3];
      const service_ids = msg.match[4].split(' ');
      const start_time = moment().format();
      const end_time = moment().add('minutes', minutes).format();

      const services = [];
      for (var service_id of Array.from(service_ids)) {
        services.push({ id: service_id, type: 'service_reference' });
      }

      const maintenance_window = { start_time, end_time, services };
      const data = { maintenance_window, services };

      msg.send(`Opening maintenance window for: ${service_ids}`);
      pagerduty.post('/maintenance_windows', data, function (err, json) {
        if (err != null) {
          robot.emit('error', err, msg);
          return;
        }

        if (json && json.maintenance_window) {
          msg.send(
            `Maintenance window created! ID: ${json.maintenance_window.id} Ends: ${json.maintenance_window.end_time}`
          );
          return;
        }

        msg.send("That didn't work. Check Hubot's logs for an error!");
      });
    });
  });

  var parseIncidentNumbers = (match) => match.split(/[ ,]+/).map((incidentNumber) => parseInt(incidentNumber));

  var reassignmentParametersForUserOrScheduleOrEscalationPolicy = function (msg, string, cb) {
    let campfireUser;
    if ((campfireUser = robot.brain.userForName(string))) {
      return campfireUserToPagerDutyUser(msg, campfireUser, (user) =>
        cb({ assigned_to_user: user.id, name: user.name })
      );
    } else {
      return pagerduty.get('/escalation_policies', { query: string }, function (err, json) {
        if (err != null) {
          robot.emit('error', err, msg);
          return;
        }

        let escalationPolicy = null;

        if (__guard__(json != null ? json.escalation_policies : undefined, (x) => x.length) === 1) {
          escalationPolicy = json.escalation_policies[0];
          // Multiple results returned and one is exact (case-insensitive)
        } else if (__guard__(json != null ? json.escalation_policies : undefined, (x1) => x1.length) > 1) {
          const matchingExactly = json.escalation_policies.filter(
            (es) => es.name.toLowerCase() === string.toLowerCase()
          );
          if (matchingExactly.length === 1) {
            escalationPolicy = matchingExactly[0];
          }
        }

        if (escalationPolicy != null) {
          return cb({ escalation_policy: escalationPolicy.id, name: escalationPolicy.name });
        } else {
          return SchedulesMatching(msg, string, function (schedule) {
            if (schedule) {
              withCurrentOncallUser(msg, schedule, (user, schedule) =>
                cb({ assigned_to_user: user.id, name: user.name })
              );
            } else {
              cb();
            }
          });
        }
      });
    }
  };

  var pagerDutyIntegrationAPI = function (msg, cmd, description, cb) {
    if (pagerDutyServiceApiKey == null) {
      msg.send('PagerDuty API service key is missing.');
      msg.send('Ensure that HUBOT_PAGERDUTY_SERVICE_API_KEY is set.');
      return;
    }

    let data = null;
    switch (cmd) {
      case 'trigger':
        data = JSON.stringify({ service_key: pagerDutyServiceApiKey, event_type: 'trigger', description });
        pagerDutyIntegrationPost(msg, data, (json) => cb(json));
    }
  };

  var formatIncident = function (inc) {
    let assigned_to;
    const summary = inc.title;
    const assignee = __guard__(
      __guard__(inc.assignments != null ? inc.assignments[0] : undefined, (x1) => x1['assignee']),
      (x) => x['summary']
    );
    if (assignee) {
      assigned_to = `- assigned to ${assignee}`;
    } else {
      ('');
    }
    return `${inc.incident_number}: ${inc.created_at} ${summary} ${assigned_to}\n`;
  };

  var updateIncidents = (msg, incidentNumbers, statusFilter, updatedStatus) =>
    campfireUserToPagerDutyUser(msg, msg.message.user, function (user) {
      const requesterId = user.id;
      if (!requesterId) {
        return;
      }

      return pagerduty.getIncidents(statusFilter, function (err, incidents) {
        let incident;
        if (err != null) {
          robot.emit('error', err, msg);
          return;
        }

        const foundIncidents = [];
        for (incident of Array.from(incidents)) {
          // FIXME this isn't working very consistently
          if (incidentNumbers.indexOf(incident.incident_number) > -1) {
            foundIncidents.push(incident);
          }
        }

        if (foundIncidents.length === 0) {
          return msg.reply(
            `Couldn't find incident(s) ${incidentNumbers.join(', ')}. Use \`${
              robot.name
            } pager incidents\` for listing.`
          );
        } else {
          const data = {
            incidents: foundIncidents.map((incident) => ({
              id: incident.id,
              type: 'incident_reference',
              status: updatedStatus,
            })),
          };

          return pagerduty.put('/incidents', data, function (err, json) {
            if (err != null) {
              robot.emit('error', err, msg);
              return;
            }

            if (json != null ? json.incidents : undefined) {
              let buffer = 'Incident';
              if (json.incidents.length > 1) {
                buffer += 's';
              }
              buffer += ' ';
              buffer += (() => {
                const result = [];
                for (incident of Array.from(json.incidents)) {
                  result.push(incident.incident_number);
                }
                return result;
              })().join(', ');
              buffer += ` ${updatedStatus}`;
              return msg.reply(buffer);
            } else {
              return msg.reply(`Problem updating incidents ${incidentNumbers.join(',')}`);
            }
          });
        }
      });
    });

  var pagerDutyIntegrationPost = (msg, json, cb) =>
    msg
      .http('https://events.pagerduty.com/generic/2010-04-15/create_event.json')
      .header('content-type', 'application/json')
      .post(json)(function (err, res, body) {
      switch (res.statusCode) {
        case 200:
          json = JSON.parse(body);
          return cb(json);
        default:
          console.log(res.statusCode);
          return console.log(body);
      }
    });

  var incidentsByUserId = (incidents, userId) =>
    incidents.filter(function (incident) {
      const assignments = incident.assignments.map((item) => item.assignee.id);
      return assignments.some((assignment) => assignment === userId);
    });

  var withCurrentOncall = (msg, schedule, cb) =>
    withCurrentOncallUser(msg, schedule, function (user, s) {
      if (user) {
        return cb(user.name, s);
      } else {
        return cb(null, s);
      }
    });

  var withCurrentOncallId = (msg, schedule, cb) =>
    withCurrentOncallUser(msg, schedule, function (user, s) {
      if (user) {
        return cb(user.id, user.name, s);
      } else {
        return cb(null, null, s);
      }
    });

  var withCurrentOncallUser = function (msg, schedule, cb) {
    const oneHour = moment().add(1, 'hours').format();
    const now = moment().format();

    let scheduleId = schedule.id;
    if (schedule instanceof Array && schedule[0]) {
      scheduleId = schedule[0].id;
    }
    if (!scheduleId) {
      msg.send("Unable to retrieve the schedule. Use 'pager schedules' to list all schedules.");
      return;
    }

    const query = {
      since: now,
      until: oneHour,
    };
    return pagerduty.get(`/schedules/${scheduleId}/users`, query, function (err, json) {
      if (err != null) {
        robot.emit('error', err, msg);
        return;
      }
      if (json.users && json.users.length > 0) {
        return cb(json.users[0], schedule);
      } else {
        return cb(null, schedule);
      }
    });
  };

  var SchedulesMatching = function (msg, q, cb) {
    const query = {
      query: q,
    };
    return pagerduty.getSchedules(query, function (err, schedules) {
      if (err != null) {
        robot.emit('error', err, msg);
        return;
      }

      return cb(schedules);
    });
  };

  var withScheduleMatching = (msg, q, cb) =>
    SchedulesMatching(msg, q, function (schedules) {
      if ((schedules != null ? schedules.length : undefined) < 1) {
        msg.send(`I couldn't find any schedules matching ${q}`);
      } else {
        for (var schedule of Array.from(schedules)) {
          cb(schedule);
        }
      }
    });

  const userEmail = (user) =>
    user.pagerdutyEmail ||
    user.email_address ||
    (user.profile != null ? user.profile.email : undefined) ||
    process.env.HUBOT_PAGERDUTY_TEST_EMAIL;

  return (campfireUserToPagerDutyUser = function (msg, user, required, cb) {
    if (typeof required === 'function') {
      cb = required;
      required = true;
    }

    //# Determine the email based on the adapter type (v4.0.0+ of the Slack adapter stores it in `profile.email`)
    const email = userEmail(user);
    const speakerEmail = userEmail(msg.message.user);

    if (!email) {
      if (!required) {
        cb(null);
        return;
      } else {
        const possessive = email === speakerEmail ? 'your' : `${user.name}'s`;
        const addressee = email === speakerEmail ? 'you' : `${user.name}`;

        msg.send(
          `Sorry, I can't figure out ${possessive} email address :( Can ${addressee} tell me with \`${robot.name} pager me as you@yourdomain.com\`?`
        );
        return;
      }
    }

    pagerduty.get('/users', { query: email }, function (err, json) {
      if (err != null) {
        robot.emit('error', err, msg);
        return;
      }

      if (json.users.length !== 1) {
        if (json.users.length === 0 && !required) {
          cb(null);
          return;
        } else {
          msg.send(
            `Sorry, I expected to get 1 user back for ${email}, but got ${json.users.length} :sweat:. If your PagerDuty email is not ${email} use \`/pager me as ${email}\``
          );
          return;
        }
      }

      cb(json.users[0]);
    });
  });
};

function __guard__(value, transform) {
  return typeof value !== 'undefined' && value !== null ? transform(value) : undefined;
}
