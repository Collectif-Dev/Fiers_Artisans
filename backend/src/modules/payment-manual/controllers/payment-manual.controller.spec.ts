import 'reflect-metadata';
import {
  THROTTLER_LIMIT,
  THROTTLER_TTL,
} from '@nestjs/throttler/dist/throttler.constants';
import { PaymentManualController } from './payment-manual.controller';

describe('PaymentManualController throttle metadata', () => {
  it('keeps a route-specific throttle on initiate only', () => {
    const initiatePayment = PaymentManualController.prototype.initiatePayment;
    const submitProof = PaymentManualController.prototype.submitProof;

    expect(
      Reflect.getMetadata(`${THROTTLER_LIMIT}default`, initiatePayment),
    ).toBe(5);
    expect(
      Reflect.getMetadata(`${THROTTLER_TTL}default`, initiatePayment),
    ).toBe(60 * 60 * 1000);

    expect(
      Reflect.getMetadata(`${THROTTLER_LIMIT}default`, submitProof),
    ).toBeUndefined();
    expect(
      Reflect.getMetadata(`${THROTTLER_TTL}default`, submitProof),
    ).toBeUndefined();
  });
});
