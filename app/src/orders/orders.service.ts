import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PaymentsService } from '../payments/payments.service';

type OrderStatus = 'created' | 'paid';

export interface Order {
  id: string;
  item: string;
  quantity: number;
  amount: number;
  status: OrderStatus;
  paymentRef?: string;
  createdAt: string;
}

export interface CreateOrderBody {
  item?: string;
  quantity?: number;
  amount?: number;
  slowPayment?: boolean;
}

@Injectable()
export class OrdersService {
  private nextId = 4;

  private readonly orders: Order[] = [
    {
      id: '1',
      item: 'observability mug',
      quantity: 1,
      amount: 18.5,
      status: 'paid',
      paymentRef: 'pay_mock_1',
      createdAt: '2026-01-10T10:00:00.000Z',
    },
    {
      id: '2',
      item: 'trace notebook',
      quantity: 2,
      amount: 24,
      status: 'paid',
      paymentRef: 'pay_mock_2',
      createdAt: '2026-01-11T10:00:00.000Z',
    },
    {
      id: '3',
      item: 'latency sticker pack',
      quantity: 5,
      amount: 7.5,
      status: 'created',
      createdAt: '2026-01-12T10:00:00.000Z',
    },
  ];

  constructor(private readonly payments: PaymentsService) {}

  list() {
    return {
      count: this.orders.length,
      data: this.orders,
    };
  }

  get(id: string) {
    const order = this.orders.find((item) => item.id === id);
    if (!order) {
      throw new NotFoundException(`order ${id} not found`);
    }

    return order;
  }

  async create(body: CreateOrderBody) {
    const item = body?.item?.trim();
    const quantity = Number(body?.quantity ?? 1);
    const amount = Number(body?.amount);

    if (!item) {
      throw new BadRequestException('item is required');
    }

    if (!Number.isFinite(quantity) || quantity < 1) {
      throw new BadRequestException('quantity must be greater than zero');
    }

    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException('amount must be greater than zero');
    }

    const order: Order = {
      id: String(this.nextId++),
      item,
      quantity,
      amount,
      status: 'created',
      createdAt: new Date().toISOString(),
    };

    const payment = await this.payments.authorize({
      amount,
      slow: Boolean(body?.slowPayment),
    });

    order.status = 'paid';
    order.paymentRef = payment.id;
    this.orders.push(order);

    return order;
  }
}
