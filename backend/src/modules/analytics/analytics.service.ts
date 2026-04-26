import { Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { ActivityLog } from './schemas/activity-log.schema';
import { AdminRealtimeService } from '../../common/realtime/admin-realtime.service';

@Injectable()
export class AnalyticsService {
  private readonly logger = new Logger(AnalyticsService.name);

  constructor(
    @InjectModel(ActivityLog.name)
    private readonly activityLogModel: Model<ActivityLog>,
    private readonly adminRealtimeService: AdminRealtimeService,
  ) {}

  async logActivity(data: {
    actorId: string;
    action: string;
    targetId?: string;
    metadata?: Record<string, any>;
    ipAddress?: string;
    userAgent?: string;
  }): Promise<void> {
    // Keep request latency low by persisting logs asynchronously.
    setImmediate(() => {
      this.activityLogModel
        .create(data)
        .then((created) => {
          this.adminRealtimeService.emit('ACTIVITY_LOGGED', {
            action: created.action,
            actorId: created.actorId,
            targetId: created.targetId,
            timestamp: created.timestamp,
          });
        })
        .catch((error) => {
          this.logger.warn(`Analytics write failed for action ${data.action}: ${error}`);
        });
    });
  }

  async countProfileViewsInLastHours(
    profileId: string,
    hours: number,
  ): Promise<number> {
    const now = new Date();
    const since = new Date(now.getTime() - hours * 60 * 60 * 1000);
    return this.activityLogModel.countDocuments({
      action: 'PROFILE_VIEW',
      targetId: profileId,
      timestamp: { $gte: since },
    });
  }

  async getDashboardStats() {
    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

    const [totalSearches, totalProfileViews, totalContacts, recentLogins] =
      await Promise.all([
        this.activityLogModel.countDocuments({
          action: 'SEARCH',
          timestamp: { $gte: thirtyDaysAgo },
        }),
        this.activityLogModel.countDocuments({
          action: 'PROFILE_VIEW',
          timestamp: { $gte: thirtyDaysAgo },
        }),
        this.activityLogModel.countDocuments({
          action: 'CONTACT_CLICK',
          timestamp: { $gte: thirtyDaysAgo },
        }),
        this.activityLogModel.countDocuments({
          action: 'LOGIN',
          timestamp: { $gte: thirtyDaysAgo },
        }),
      ]);

    return {
      period: '30_days',
      totalSearches,
      totalProfileViews,
      totalContacts,
      recentLogins,
    };
  }

  async getLogs(page = 1, limit = 50, action?: string) {
    const filter: Record<string, any> = {};
    if (action) filter.action = action;

    const [data, total] = await Promise.all([
      this.activityLogModel
        .find(filter)
        .sort({ timestamp: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .exec(),
      this.activityLogModel.countDocuments(filter),
    ]);

    return { data, total, page, limit };
  }
}
