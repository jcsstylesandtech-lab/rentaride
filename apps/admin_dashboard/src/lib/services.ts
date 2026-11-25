import { Bike, Car, Truck } from "lucide-react";

/** The kinds of work a driver does on Rent A Ride (drivers.service_type). */
export type ServiceType = "ride" | "dispatch" | "delivery";

export const SERVICES: { value: ServiceType; label: string; short: string; icon: React.ElementType; hint: string }[] = [
  { value: "ride", label: "Ride drivers", short: "Ride", icon: Car, hint: "Carry passengers" },
  { value: "dispatch", label: "Dispatch riders", short: "Dispatch", icon: Bike, hint: "Bike couriers for small packages" },
  { value: "delivery", label: "Delivery drivers", short: "Delivery", icon: Truck, hint: "Cars and vans for parcels and goods" },
];

export function isService(v: string | null | undefined): v is ServiceType {
  return v === "ride" || v === "dispatch" || v === "delivery";
}

export function serviceInfo(v: ServiceType) {
  return SERVICES.find((s) => s.value === v)!;
}
