# Database-SQL-development
# FFK Café Restaurant Management System

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14+-blue.svg)](https://www.postgresql.org/)

Professional database solution, customized for cafe and restaurant scenarios. Provides complete menu management, order processing and employee authority control system to optimize catering business operation efficiency.

## Core Function Highlights

- ​**Multi-type order processing**​: Seamless support for inheritance management of dine-in/takeout/delivery orders

- ​**Smart menu system**​: Dynamic coffee combination solutions (coffee + milk products = 15+ combinations)

- ​**Authorization security control**​: Employee access control system with password verification

- ​**Real-time inventory management**​: Linked update of food inventory and order processing

- ​**Three-tier classification system**​: Flexible and scalable menu classification structure

## Technical architecture

```mermaid
erDiagram
ORDERS ||--o{ DINE_IN : "Inherit"
ORDERS ||--o{ DELIVERY : "Inherit"
ORDERS ||--o{ TAKE_OUT : "Inherit"
MENU_ITEMS }o--|| CATEGORY : "Three-level classification"
PAYMENTS ||--o{ CREDIT_CARD : "Weak Entity"

├── schema.sql # Database table structure design
├── functions.sql # Stored procedures and business functions
├── sample_data.sql # Sample business data
├── constraints.sql # Data integrity constraints
└── queries.sql # Common business query examples
