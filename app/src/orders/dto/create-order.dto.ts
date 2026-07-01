import { Transform, Type } from 'class-transformer';
import { IsBoolean, IsInt, IsNotEmpty, IsNumber, IsString, Min } from 'class-validator';

export class CreateOrderDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @IsNotEmpty()
  item!: string;

  @Transform(({ value }) => (value === undefined ? 1 : value))
  @Type(() => Number)
  @IsInt()
  @Min(1)
  quantity = 1;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount!: number;

  @Transform(({ value }) => (value === undefined ? false : value))
  @IsBoolean()
  slowPayment = false;
}
