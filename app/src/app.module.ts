import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';
import { OrdersModule } from './orders/orders.module';
import { PaymentsModule } from './payments/payments.module';

@Module({
  imports: [OrdersModule, PaymentsModule],
  controllers: [HealthController],
})
export class AppModule {}
