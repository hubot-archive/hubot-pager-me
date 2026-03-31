/**
 * TypeScript definitions for PagerDuty Hubot adapter
 * Provides IDE support and type checking for both TypeScript and JavaScript projects
 */

/**
 * Hubot message object interface
 */
export interface HubotMessage {
  send: (text: string | string[]) => void;
  reply: (text: string) => void;
  finish?: () => void;
  message?: {
    user?: HubotUser;
  };
}

/**
 * Hubot user interface
 */
export interface HubotUser {
  id?: string;
  name: string;
  email_address?: string;
  pagerdutyEmail?: string;
}

/**
 * PagerDuty Incident object
 */
export interface PagerDutyIncident {
  id: string;
  incident_number: number;
  status: 'triggered' | 'acknowledged' | 'resolved';
  title: string;
  description?: string;
  created_at: string;
  html_url: string;
  assigned_to_user?: PagerDutyUser;
  assigned_via: 'escalation_policy' | 'escalation_rule' | 'direct' | 'user_override';
}

/**
 * PagerDuty Schedule object
 */
export interface PagerDutySchedule {
  id: string;
  name: string;
  html_url: string;
  description?: string;
  time_zone?: string;
}

/**
 * PagerDuty Schedule Entry
 */
export interface PagerDutyScheduleEntry {
  id: string;
  start: string;
  end: string;
  user: PagerDutyUser;
}

/**
 * PagerDuty User object
 */
export interface PagerDutyUser {
  id: string;
  name: string;
  email: string;
  html_url: string;
  summary?: string;
  type?: string;
}

/**
 * PagerDuty Service object
 */
export interface PagerDutyService {
  id: string;
  name: string;
  html_url: string;
  description?: string;
}

/**
 * PagerDuty Override object
 */
export interface PagerDutyOverride {
  id: string;
  start: string;
  end: string;
  user: PagerDutyUser;
}

/**
 * API Response callback type
 */
export type ApiCallback<T> = (error: Error | null, data?: T) => void;

/**
 * PagerDuty Adapter interface
 * Provides access to PagerDuty API through PagerDuty.com
 */
export interface PagerDutyAdapter {
  /**
   * Make an HTTP GET request to PagerDuty API
   * @param url The API endpoint path (e.g., '/incidents')
   * @param query Optional query parameters
   * @param callback Called with (error, data)
   */
  get(url: string, query?: Record<string, any>, callback?: ApiCallback<any>): void;
  get(url: string, callback?: ApiCallback<any>): void;

  /**
   * Make an HTTP POST request to PagerDuty API
   * @param url The API endpoint path
   * @param data Request body
   * @param callback Called with (error, data)
   */
  post(url: string, data: any, callback: ApiCallback<any>): void;

  /**
   * Make an HTTP PUT request to PagerDuty API
   * @param url The API endpoint path
   * @param data Request body
   * @param callback Called with (error, data)
   */
  put(url: string, data: any, callback: ApiCallback<any>): void;

  /**
   * Make an HTTP DELETE request to PagerDuty API
   * @param url The API endpoint path
   * @param callback Called with (error, success)
   */
  delete(url: string, callback: ApiCallback<boolean>): void;

  /**
   * Get an incident by incident_key
   * @param incident_key The incident key to search for
   * @param callback Called with (error, incidents)
   */
  getIncident(incident_key: string, callback: ApiCallback<PagerDutyIncident[]>): void;

  /**
   * Get incidents filtered by status
   * @param status Comma-separated status values (e.g., 'triggered,acknowledged')
   * @param callback Called with (error, incidents)
   */
  getIncidents(status: string, callback: ApiCallback<PagerDutyIncident[]>): void;

  /**
   * Get schedules, optionally filtered by query
   * @param query Optional query parameters with optional callback
   * @param callback Optional callback called with (error, schedules)
   */
  getSchedules(query?: Record<string, any> | ApiCallback<PagerDutySchedule[]>, callback?: ApiCallback<PagerDutySchedule[]>): void;

  /**
   * Check for missing environment configuration
   * @param msg Hubot message object with send method
   * @returns true if any required env vars are missing
   */
  missingEnvironmentForApi(msg: HubotMessage): boolean;
}

/**
 * Export the adapter module
 */
export const pagerduty: PagerDutyAdapter;

/**
 * Hubot robot interface with PagerDuty integration
 */
export interface HubotRobot {
  name: string;
  respond: (regex: RegExp, callback: (msg: HubotMessage) => void) => void;
  hear: (regex: RegExp, callback: (msg: HubotMessage) => void) => void;
  messageRoom: (room: string, text: string | string[]) => void;
  brain: {
    userForName: (name: string) => HubotUser | undefined;
    users: () => Record<string, HubotUser>;
  };
  logger: {
    debug: (message: string) => void;
    info: (message: string) => void;
    warning: (message: string) => void;
    error: (message: string) => void;
  };
  emit: (event: string, error: Error, msg: HubotMessage) => void;
  helpCommands: () => string[];
  router: {
    post: (path: string, handler: (req: any, res: any) => void) => void;
  };
}

// Script/webhook types

export interface IncidentFormatOptions {
  includeUrl?: boolean;
  includeAssignee?: boolean;
  includeStatus?: boolean;
  timezone?: string;
}

export interface ScheduleOverrideOptions {
  startTime: string;
  endTime: string;
  userId: string;
  type: 'user_reference';
}

export interface IncidentUpdateOptions {
  status: 'acknowledged' | 'resolved';
  escalation_policy?: {
    id: string;
    type: string;
  };
}

export interface NoteOptions {
  content: string;
  requester_id?: string;
}

export interface WebhookPayload {
  messages: Array<{
    type: string;
    data: {
      incident: PagerDutyIncident;
    };
  }>;
}

export type WebhookMessageType =
  | 'incident.trigger'
  | 'incident.acknowledge'
  | 'incident.resolve'
  | 'incident.unacknowledge'
  | 'incident.assign'
  | 'incident.escalate'
  | 'incident.delegate';

export interface PagerDutyScript {
  (robot: HubotRobot): void;
}

export interface PagerDutyWebhookScript {
  (robot: HubotRobot): void;
}

export interface GetUserCallback {
  (error: Error | null, user?: PagerDutyUser): void;
}

export interface GetSchedulesCallback {
  (schedules: PagerDutySchedule[]): void;
}

export interface CommandContext {
  robot: HubotRobot;
  msg: HubotMessage;
  userId?: string;
  scheduleId?: string;
  incidentId?: string;
  query?: string;
}

export interface IncidentQueryResult {
  incidents: PagerDutyIncident[];
  limit?: number;
  offset?: number;
  total?: number;
  more?: boolean;
}

export interface ScheduleQueryResult {
  schedules: PagerDutySchedule[];
  limit?: number;
  offset?: number;
  total?: number;
  more?: boolean;
}
