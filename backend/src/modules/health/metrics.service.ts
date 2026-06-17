import { Injectable } from '@nestjs/common';
import { Registry, collectDefaultMetrics } from 'prom-client';

let defaultMetricsInitialized = false;
const metricsRegistry = new Registry();

@Injectable()
export class MetricsService {
  private readonly registry = metricsRegistry;

  constructor() {
    if (!defaultMetricsInitialized) {
      collectDefaultMetrics({ register: this.registry });
      defaultMetricsInitialized = true;
    }
  }

  getContentType(): string {
    return this.registry.contentType;
  }

  async getMetricsSnapshot(): Promise<string> {
    return this.registry.metrics();
  }
}
