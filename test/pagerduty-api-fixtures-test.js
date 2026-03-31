/**
 * Test Fixtures for PagerDuty API Responses
 * Validates that fixtures match real PagerDuty API v2 response structures
 */

const assert = require('assert');
const fixtures = require('./pagerduty-api-fixtures');

describe('PagerDuty API Response Fixtures', () => {
  describe('Fixtures Validation', () => {
    it('should have valid incidents response structure', () => {
      assert.ok(fixtures.incidentsResponse);
      assert.ok(Array.isArray(fixtures.incidentsResponse.incidents));
      assert(fixtures.incidentsResponse.incidents.length > 0);
      
      const incident = fixtures.incidentsResponse.incidents[0];
      assert.ok(incident.id);
      assert.ok(incident.incident_number);
      assert.ok(incident.summary);
      assert.ok(incident.status);
      assert.ok(incident.service);
    });

    it('should have valid schedules response structure', () => {
      assert.ok(fixtures.schedulesResponse);
      assert.ok(Array.isArray(fixtures.schedulesResponse.schedules));
      assert(fixtures.schedulesResponse.schedules.length > 0);
      
      const schedule = fixtures.schedulesResponse.schedules[0];
      assert.ok(schedule.id);
      assert.ok(schedule.name);
      assert.ok(schedule.time_zone);
    });

    it('should have valid schedule with entries response', () => {
      assert.ok(fixtures.scheduleWithEntriesResponse);
      assert.ok(fixtures.scheduleWithEntriesResponse.schedule);
      assert.ok(fixtures.scheduleWithEntriesResponse.schedule.final_schedule);
      assert.ok(Array.isArray(fixtures.scheduleWithEntriesResponse.schedule.final_schedule.rendered_schedule_entries));
    });

    it('should have valid overrides response structure', () => {
      assert.ok(fixtures.overridesResponse);
      assert.ok(Array.isArray(fixtures.overridesResponse.overrides));
      assert(fixtures.overridesResponse.overrides.length > 0);
      
      const override = fixtures.overridesResponse.overrides[0];
      assert.ok(override.id);
      assert.ok(override.user);
      assert.ok(override.start);
      assert.ok(override.end);
    });

    it('should have valid notes response structure', () => {
      assert.ok(fixtures.notesResponse);
      assert.ok(Array.isArray(fixtures.notesResponse.notes));
      assert(fixtures.notesResponse.notes.length > 0);
      
      const note = fixtures.notesResponse.notes[0];
      assert.ok(note.id);
      assert.ok(note.content);
      assert.ok(note.user);
    });

    it('should have valid user response structure', () => {
      assert.ok(fixtures.userResponse);
      assert.ok(fixtures.userResponse.user);
      assert.ok(fixtures.userResponse.user.id);
      assert.ok(fixtures.userResponse.user.email);
      assert.ok(fixtures.userResponse.user.name);
    });

    it('should have valid error responses', () => {
      assert.ok(fixtures.errorResponses.notFound);
      assert.ok(fixtures.errorResponses.unauthorized);
      assert.ok(fixtures.errorResponses.rateLimited);
      
      assert.ok(fixtures.errorResponses.notFound.error);
      assert.ok(fixtures.errorResponses.unauthorized.error);
      assert.ok(fixtures.errorResponses.rateLimited.error);
    });
  });

  describe('Fixture Response Formats', () => {
    it('incidents have proper status values', () => {
      const statuses = new Set(['triggered', 'acknowledged', 'resolved']);
      fixtures.incidentsResponse.incidents.forEach((incident) => {
        assert(statuses.has(incident.status), `Invalid incident status: ${incident.status}`);
      });
    });

    it('incidents have service references', () => {
      fixtures.incidentsResponse.incidents.forEach((incident) => {
        assert.ok(incident.service.id);
        assert.ok(incident.service.summary);
        assert.ok(incident.service.type === 'service_reference');
      });
    });

    it('schedules have time zones', () => {
      fixtures.schedulesResponse.schedules.forEach((schedule) => {
        assert.ok(schedule.time_zone);
        assert.ok(schedule.time_zone.includes('/'));
      });
    });

    it('overrides have user and time range', () => {
      fixtures.overridesResponse.overrides.forEach((override) => {
        assert.ok(override.user);
        assert.ok(override.start);
        assert.ok(override.end);
        assert(new Date(override.start) <= new Date(override.end));
      });
    });

    it('notes have timestamps', () => {
      fixtures.notesResponse.notes.forEach((note) => {
        assert.ok(note.created_at);
        assert.ok(new Date(note.created_at).getTime() > 0);
      });
    });
  });

  describe('Fixture Pagination Info', () => {
    it('incidents response includes pagination', () => {
      assert.strictEqual(typeof fixtures.incidentsResponse.offset, 'number');
      assert.strictEqual(typeof fixtures.incidentsResponse.limit, 'number');
      assert.strictEqual(typeof fixtures.incidentsResponse.total, 'number');
      assert.strictEqual(typeof fixtures.incidentsResponse.more, 'boolean');
    });

    it('schedules response includes pagination', () => {
      assert.strictEqual(typeof fixtures.schedulesResponse.offset, 'number');
      assert.strictEqual(typeof fixtures.schedulesResponse.limit, 'number');
      assert.strictEqual(typeof fixtures.schedulesResponse.total, 'number');
      assert.strictEqual(typeof fixtures.schedulesResponse.more, 'boolean');
    });
  });

  describe('Fixture API Structure Accuracy', () => {
    it('incidents match PagerDuty API v2 schema', () => {
      const incident = fixtures.incidentsResponse.incidents[0];
      
      // Required fields per API docs
      assert.ok(incident.id, 'incident must have id');
      assert.ok(incident.incident_number, 'incident must have incident_number');
      assert.ok(incident.status, 'incident must have status');
      assert.ok(incident.created_at, 'incident must have created_at');
      assert.ok(incident.service, 'incident must have service');
      assert.ok(incident.type === 'incident_reference', 'incident type should be incident_reference');
    });

    it('schedules match PagerDuty API v2 schema', () => {
      const schedule = fixtures.schedulesResponse.schedules[0];
      
      assert.ok(schedule.id, 'schedule must have id');
      assert.ok(schedule.name, 'schedule must have name');
      assert.ok(schedule.type === 'schedule', 'schedule type should be schedule');
    });

    it('overrides have correct structure for API calls', () => {
      const override = fixtures.overridesResponse.overrides[0];
      
      assert.ok(override.id, 'override must have id');
      assert.ok(override.type === 'override', 'override type should be override');
      assert.ok(override.user, 'override must have user');
      assert.ok(override.start, 'override must have start');
      assert.ok(override.end, 'override must have end');
    });
  });

  describe('Update/Create Response Structures', () => {
    it('add note response has proper structure', () => {
      const { note } = fixtures.addNoteResponse;
      
      assert.ok(note.id);
      assert.ok(note.content);
      assert.ok(note.created_at);
      assert.ok(note.user);
    });

    it('create override response has proper structure', () => {
      const { override } = fixtures.createOverrideResponse;
      
      assert.ok(override.id);
      assert.ok(override.type === 'override');
      assert.ok(override.user);
      assert.ok(override.start);
      assert.ok(override.end);
    });

    it('update incident response has proper structure', () => {
      const { incidents } = fixtures.updateIncidentResponse;
      
      assert.ok(Array.isArray(incidents));
      assert(incidents.length > 0);
      
      const incident = incidents[0];
      assert.ok(incident.id);
      assert.ok(incident.status);
      assert.ok(incident.last_status_change_at);
    });
  });

  describe('Error Response Structures', () => {
    it('404 error response is properly formatted', () => {
      assert.ok(fixtures.errorResponses.notFound.error);
      assert.ok(typeof fixtures.errorResponses.notFound.error.code === 'number');
      assert.ok(typeof fixtures.errorResponses.notFound.error.message === 'string');
    });

    it('401 error response is properly formatted', () => {
      assert.ok(fixtures.errorResponses.unauthorized.error);
      assert.ok(typeof fixtures.errorResponses.unauthorized.error.code === 'number');
      assert.ok(fixtures.errorResponses.unauthorized.error.message.includes('Invalid'));
    });

    it('429 error response is properly formatted', () => {
      assert.ok(fixtures.errorResponses.rateLimited.error);
      assert.ok(fixtures.errorResponses.rateLimited.error.message.includes('rate limit'));
    });
  });

  describe('Documentation Examples', () => {
    it('all fixtures can be used as examples in documentation', () => {
      // Ensure all fixtures are non-empty and properly formatted
      const allFixtures = {
        incidents: fixtures.incidentsResponse,
        schedules: fixtures.schedulesResponse,
        scheduleWithEntries: fixtures.scheduleWithEntriesResponse,
        overrides: fixtures.overridesResponse,
        notes: fixtures.notesResponse,
        user: fixtures.userResponse,
      };

      for (const [name, fixture] of Object.entries(allFixtures)) {
        assert.ok(fixture, `Fixture ${name} should exist`);
        assert.ok(Object.keys(fixture).length > 0, `Fixture ${name} should not be empty`);
      }
    });
  });
});
