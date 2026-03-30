/**
 * Test fixtures - Real PagerDuty API responses for mocking
 * Based on PagerDuty REST API v2 documentation
 */

/**
 * Realistic PagerDuty incident response
 */
const incidentsResponse = {
  incidents: [
    {
      incident_number: 1,
      id: 'INC123ABC',
      type: 'incident_reference',
      summary: '[#1] Server is down',
      description: 'Main production server is not responding',
      created_at: '2026-03-29T10:00:00Z',
      status: 'triggered',
      pending_actions: [],
      incident_key: 'baf7cf21b1da41b4fde83c0d05b26c40',
      service: {
        id: 'PBGPBFY',
        type: 'service_reference',
        summary: 'Production API',
        self: 'https://api.pagerduty.com/services/PBGPBFY',
        html_url: 'https://subdomain.pagerduty.com/services/PBGPBFY',
      },
      assigned_via: 'escalation_policy',
      first_trigger_log_entry: {
        id: 'Q02WNKLZWHSEKV',
        type: 'trigger_log_entry_reference',
        summary: 'Triggered through the website',
        self: 'https://api.pagerduty.com/log_entries/Q02WNKLZWHSEKV?incident_id=INC123ABC',
        html_url: 'https://subdomain.pagerduty.com/incidents/INC123ABC/log_entries/Q02WNKLZWHSEKV',
      },
      escalation_policy: {
        id: 'PT20VPA',
        type: 'escalation_policy_reference',
        summary: 'Another Escalation Policy',
        self: 'https://api.pagerduty.com/escalation_policies/PT20VPA',
        html_url: 'https://subdomain.pagerduty.com/escalation_policies/PT20VPA',
      },
      teams: [],
      urgency: 'high',
      id_response_play: null,
      escalation_policy_id: 'PT20VPA',
      assigned_to_user: {
        id: 'PIJ90N6',
        type: 'user_reference',
        summary: 'John Doe',
        self: 'https://api.pagerduty.com/users/PIJ90N6',
        html_url: 'https://subdomain.pagerduty.com/users/PIJ90N6',
        email: 'john@example.com',
      },
      last_status_change_at: '2026-03-29T10:00:00Z',
      last_status_change_by: {
        id: 'PIJ90N6',
        type: 'service_reference',
        summary: 'Production API',
        self: 'https://api.pagerduty.com/services/PBGPBFY',
        html_url: 'https://subdomain.pagerduty.com/services/PBGPBFY',
      },
      first_resolved_at: null,
      last_resolved_at: null,
      last_resolved_by: null,
      resolved_at: null,
      resolved_by: null,
      html_url: 'https://subdomain.pagerduty.com/incidents/INC123ABC',
      self: 'https://api.pagerduty.com/incidents/INC123ABC',
    },
    {
      incident_number: 2,
      id: 'INC456DEF',
      type: 'incident_reference',
      summary: '[#2] Database connection timeout',
      description: 'Unable to connect to database pool',
      created_at: '2026-03-28T15:30:00Z',
      status: 'acknowledged',
      pending_actions: [],
      incident_key: 'database-timeout-2026-03',
      service: {
        id: 'PFGPBFY2',
        type: 'service_reference',
        summary: 'Database Service',
        self: 'https://api.pagerduty.com/services/PFGPBFY2',
        html_url: 'https://subdomain.pagerduty.com/services/PFGPBFY2',
      },
      assigned_via: 'escalation_policy',
      escalation_policy: {
        id: 'PT20VPA',
        type: 'escalation_policy_reference',
        summary: 'Another Escalation Policy',
        self: 'https://api.pagerduty.com/escalation_policies/PT20VPA',
        html_url: 'https://subdomain.pagerduty.com/escalation_policies/PT20VPA',
      },
      teams: [],
      urgency: 'medium',
      assigned_to_user: {
        id: 'PIJ90N7',
        type: 'user_reference',
        summary: 'Jane Smith',
        self: 'https://api.pagerduty.com/users/PIJ90N7',
        html_url: 'https://subdomain.pagerduty.com/users/PIJ90N7',
        email: 'jane@example.com',
      },
      last_status_change_at: '2026-03-28T16:00:00Z',
      html_url: 'https://subdomain.pagerduty.com/incidents/INC456DEF',
      self: 'https://api.pagerduty.com/incidents/INC456DEF',
    },
  ],
  offset: 0,
  limit: 25,
  total: 2,
  more: false,
};

/**
 * Realistic PagerDuty schedules response
 */
const schedulesResponse = {
  schedules: [
    {
      id: 'PIJ90N6',
      type: 'schedule',
      summary: 'Primary On-Call',
      description: 'Primary on-call schedule for infrastructure',
      self: 'https://api.pagerduty.com/schedules/PIJ90N6',
      html_url: 'https://subdomain.pagerduty.com/schedules/PIJ90N6',
      name: 'Primary On-Call',
      time_zone: 'America/Los_Angeles',
      escalation_policies: [
        {
          id: 'PT20VPA',
          type: 'escalation_policy_reference',
          summary: 'Default',
          self: 'https://api.pagerduty.com/escalation_policies/PT20VPA',
          html_url: 'https://subdomain.pagerduty.com/escalation_policies/PT20VPA',
        },
      ],
      users: [
        {
          id: 'PJIEFFF',
          type: 'user_reference',
          summary: 'Alice Johnson',
          self: 'https://api.pagerduty.com/users/PJIEFFF',
          html_url: 'https://subdomain.pagerduty.com/users/PJIEFFF',
        },
        {
          id: 'PIJ90N7',
          type: 'user_reference',
          summary: 'Bob Wilson',
          self: 'https://api.pagerduty.com/users/PIJ90N7',
          html_url: 'https://subdomain.pagerduty.com/users/PIJ90N7',
        },
      ],
      teams: [],
    },
    {
      id: 'PIJ90N8',
      type: 'schedule',
      summary: 'Secondary On-Call',
      description: 'Secondary on-call schedule',
      self: 'https://api.pagerduty.com/schedules/PIJ90N8',
      html_url: 'https://subdomain.pagerduty.com/schedules/PIJ90N8',
      name: 'Secondary On-Call',
      time_zone: 'America/New_York',
      escalation_policies: [],
      users: [
        {
          id: 'PIJ90N9',
          type: 'user_reference',
          summary: 'Carol Davis',
          self: 'https://api.pagerduty.com/users/PIJ90N9',
          html_url: 'https://subdomain.pagerduty.com/users/PIJ90N9',
        },
      ],
      teams: [],
    },
  ],
  offset: 0,
  limit: 25,
  total: 2,
  more: false,
};

/**
 * Realistic schedule with rendered entries response
 */
const scheduleWithEntriesResponse = {
  schedule: {
    id: 'PIJ90N6',
    type: 'schedule',
    summary: 'Primary On-Call',
    self: 'https://api.pagerduty.com/schedules/PIJ90N6',
    html_url: 'https://subdomain.pagerduty.com/schedules/PIJ90N6',
    name: 'Primary On-Call',
    time_zone: 'America/Los_Angeles',
    final_schedule: {
      name: 'Primary On-Call',
      rendered_schedule_entries: [
        {
          id: 'SCHEDENTRY001',
          summary: 'Alice Johnson on-call',
          start: '2026-03-29T00:00:00-07:00',
          end: '2026-03-30T00:00:00-07:00',
          user: {
            id: 'PJIEFFF',
            type: 'user_reference',
            summary: 'Alice Johnson',
            self: 'https://api.pagerduty.com/users/PJIEFFF',
            html_url: 'https://subdomain.pagerduty.com/users/PJIEFFF',
            email: 'alice@example.com',
          },
        },
        {
          id: 'SCHEDENTRY002',
          summary: 'Bob Wilson on-call',
          start: '2026-03-30T00:00:00-07:00',
          end: '2026-03-31T00:00:00-07:00',
          user: {
            id: 'PIJ90N7',
            type: 'user_reference',
            summary: 'Bob Wilson',
            self: 'https://api.pagerduty.com/users/PIJ90N7',
            html_url: 'https://subdomain.pagerduty.com/users/PIJ90N7',
            email: 'bob@example.com',
          },
        },
      ],
    },
  },
};

/**
 * Schedule overrides response
 */
const overridesResponse = {
  overrides: [
    {
      id: 'OVERRIDE001',
      summary: 'Carol Davis override for Primary',
      type: 'override',
      self: 'https://api.pagerduty.com/schedules/PIJ90N6/overrides/OVERRIDE001',
      start: '2026-03-31T00:00:00-07:00',
      end: '2026-04-01T00:00:00-07:00',
      user: {
        id: 'PIJ90N9',
        type: 'user_reference',
        summary: 'Carol Davis',
        self: 'https://api.pagerduty.com/users/PIJ90N9',
        html_url: 'https://subdomain.pagerduty.com/users/PIJ90N9',
        email: 'carol@example.com',
      },
    },
  ],
  offset: 0,
  limit: 25,
  total: 1,
  more: false,
};

/**
 * Incident notes response
 */
const notesResponse = {
  notes: [
    {
      id: 'NOTE001',
      type: 'note',
      summary: 'Started investigating the issue',
      details: 'Started investigating the issue',
      created_at: '2026-03-29T10:15:00Z',
      user: {
        id: 'PIJ90N6',
        type: 'user_reference',
        summary: 'John Doe',
        self: 'https://api.pagerduty.com/users/PIJ90N6',
        html_url: 'https://subdomain.pagerduty.com/users/PIJ90N6',
        email: 'john@example.com',
      },
      content: 'Started investigating the issue',
    },
    {
      id: 'NOTE002',
      type: 'note',
      summary: 'Found the root cause',
      details: 'Found the root cause - database connection pool exhausted',
      created_at: '2026-03-29T10:30:00Z',
      user: {
        id: 'PIJ90N6',
        type: 'user_reference',
        summary: 'John Doe',
        self: 'https://api.pagerduty.com/users/PIJ90N6',
        html_url: 'https://subdomain.pagerduty.com/users/PIJ90N6',
        email: 'john@example.com',
      },
      content: 'Found the root cause - database connection pool exhausted',
    },
  ],
  offset: 0,
  limit: 25,
  total: 2,
  more: false,
};

/**
 * User response
 */
const userResponse = {
  user: {
    id: 'PIJ90N6',
    type: 'user',
    name: 'John Doe',
    email: 'john@example.com',
    summary: 'John Doe',
    self: 'https://api.pagerduty.com/users/PIJ90N6',
    html_url: 'https://subdomain.pagerduty.com/users/PIJ90N6',
    avatar_url: 'https://gravatar.com/avatar/example',
    color: '#6C7B7D',
    role: 'user',
    locale: 'en-US',
    time_zone: 'America/Los_Angeles',
    description: null,
    billed: true,
    teams: [],
    notification_rules: [],
    coordinated_at: '2026-03-29T10:00:00Z',
  },
};

/**
 * Create override response
 */
const createOverrideResponse = {
  override: {
    id: 'OVERRIDE_NEW001',
    type: 'override',
    start: '2026-04-01T00:00:00Z',
    end: '2026-04-02T00:00:00Z',
    user: {
      id: 'PIJ90N6',
      type: 'user_reference',
      summary: 'John Doe',
      self: 'https://api.pagerduty.com/users/PIJ90N6',
      html_url: 'https://subdomain.pagerduty.com/users/PIJ90N6',
      email: 'john@example.com',
    },
  },
};

/**
 * Add note response
 */
const addNoteResponse = {
  note: {
    id: 'NOTE_NEW001',
    type: 'note',
    summary: 'New note added',
    content: 'This is a new note',
    created_at: '2026-03-29T11:00:00Z',
    user: {
      id: 'PIJ90N6',
      type: 'user_reference',
      summary: 'John Doe',
      self: 'https://api.pagerduty.com/users/PIJ90N6',
      html_url: 'https://subdomain.pagerduty.com/users/PIJ90N6',
      email: 'john@example.com',
    },
  },
};

/**
 * Update incident response
 */
const updateIncidentResponse = {
  incidents: [
    {
      incident_number: 1,
      id: 'INC123ABC',
      summary: '[#1] Server is down',
      status: 'acknowledged',
      created_at: '2026-03-29T10:00:00Z',
      last_status_change_at: '2026-03-29T10:05:00Z',
      html_url: 'https://subdomain.pagerduty.com/incidents/INC123ABC',
      self: 'https://api.pagerduty.com/incidents/INC123ABC',
      assigned_to_user: {
        id: 'PIJ90N6',
        type: 'user_reference',
        summary: 'John Doe',
        email: 'john@example.com',
      },
    },
  ],
};

/**
 * Error responses
 */
const errorResponses = {
  notFound: {
    error: {
      code: 2001,
      message: 'The request contains characters that are not allowed.',
    },
  },
  unauthorized: {
    error: {
      code: 3001,
      message: 'Invalid API token',
    },
  },
  rateLimited: {
    error: {
      code: 3000,
      message: 'You have exceeded the rate limit',
    },
  },
};

module.exports = {
  incidentsResponse,
  schedulesResponse,
  scheduleWithEntriesResponse,
  overridesResponse,
  notesResponse,
  userResponse,
  createOverrideResponse,
  addNoteResponse,
  updateIncidentResponse,
  errorResponses,
};
