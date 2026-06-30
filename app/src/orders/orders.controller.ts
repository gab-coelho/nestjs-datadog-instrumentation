import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { CreateOrderBody, OrdersService } from './orders.service';

@Controller('orders')
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Get()
  list() {
    return this.orders.list();
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.orders.get(id);
  }

  @Post()
  create(@Body() body: CreateOrderBody) {
    return this.orders.create(body);
  }
}
