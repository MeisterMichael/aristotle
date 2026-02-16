# CLAUDE.md - Aristotle Engine

## Purpose

Aristotle is an analytics ETL and data warehouse engine. It extracts, transforms, and loads e-commerce transaction data from multiple sources (Bazaar, Amazon, Shopify) into a read-only analytics database for reporting. It also processes marketing spend data from Facebook Ads and Google Ads, and tracks events from Bunyan.

**Version:** 3.14.0

## Key Models

### Transaction Models

- **`Aristotle::TransactionItem`** - Primary line item model for analytics
  - `enum offer_type`: `subscription: 1`, `default: 0`, `renewal: 2`
  - `enum payment_type`: `no_payment_type: 0`, `credit_card: 1`, `paypal: 2`, `amazon_payments: 3`, `cash: 4`, `cheque: 5`, `bitpay: 6`
  - `enum status`: `cancelled: -2`, `failed: -1`, `pending: 0`, `pre_ordered: 1`, `on_hold: 8`, `processing: 9`, `completed: 10`, `refunded: 11`
  - `enum transaction_type`: `charge: 1`, `refund: -1`
  - Associations: order, subscription, offer, product, customer, location, channel_partner, warehouse, wholesale_client, experiment, transaction_skus
  - Tags: `acts_as_taggable_array_on :tags`

- **`Aristotle::TransactionSku`** - SKU-level breakdown of transaction items (mirrors TransactionItem enums)

- **`Aristotle::Order`** - Order header data
  - `enum status`: `cancelled: -2`, `failed: -1`, `pending: 0`, `pre_ordered: 1`, `on_hold: 8`, `processing: 9`, `completed: 10`, `refunded: 11`
  - Associations: customer, channel_partner, location, billing_location, shipping_location, wholesale_client, experiment, experiment_variant

- **`Aristotle::Subscription`** - Recurring subscription tracking
  - `enum status`: `active: 1`, `canceled: -1`, `on_hold: 0`
  - `enum payment_type`: same as TransactionItem

### Product Models

- **`Aristotle::Product`** - `enum status`: `active: 1`, `draft: 0`, `unused: -1`
- **`Aristotle::Offer`** - `enum offer_type`: `subscription: 1`, `default: 0`, `renewal: 2`
- **`Aristotle::OfferSku`** - Maps SKUs to offers
- **`Aristotle::Sku`** - Individual ingredient/component
- **`Aristotle::OfferSet`** / **`Aristotle::OfferSetOffer`** / **`Aristotle::OfferSetProduct`** - Bundle/collection groupings

### Customer & Location

- **`Aristotle::Customer`** - `enum status`: `redacted: -100`, `guest: 0`, `active: 1`, `suspended: 2`
- **`Aristotle::Location`** - Geographic address data
- **`Aristotle::ChannelPartner`** - Affiliate/reseller. `enum status`: `active: 1`, `suspended: 2`. Self-referential parent for recruitment hierarchy.
- **`Aristotle::WholesaleClient`** - B2B customer accounts

### Marketing

- **`Aristotle::EmailCampaign`** - Email marketing campaigns
- **`Aristotle::MarketingSpend`** - Daily marketing spend metrics. `enum purpose`: `spend: 0`, `research: 1`
- **`Aristotle::MarketingSpendSet`** - Aggregates multi-day spend into daily records
- **`Aristotle::Coupon`** - `enum discount_type`: `percent: 1`, `recurring_percent: 2`, `fixed_cart: 3`, `percent_product: 4`
- **`Aristotle::CouponUse`** - Coupon usage tracking

### Experiments

- **`Aristotle::Experiment`** / **`Aristotle::ExperimentVariant`** / **`Aristotle::ExperimentParticipation`**

### Other

- **`Aristotle::Review`** - `enum status`: `trash: -50`, `spam: -40`, `removed: -20`, `compliance_review: -15`, `to_moderate: -10`, `draft: 0`, `active: 1`
- **`Aristotle::Warehouse`** - Fulfillment warehouse
- **`Aristotle::UpsellImpression`** - Tracks upsell offers shown, accepted, and purchased
- **`Aristotle::CurrencyExchange`** - Historical exchange rates. `find_rate(from, to, at:)` for bidirectional lookup.
- **`Aristotle::Event`** - Generic event tracking with associations to all major models
- **`Aristotle::Report`** - Abstract base class for custom reports with columns, filters, CSV export

## Key Services (ETL Layer)

### Base: EcomEtl

Abstract ETL processor with constants for STATE_ATTRIBUTES, NUMERIC_ATTRIBUTES, TIMESTAMP_ATTRIBUTES, DENORMALIZED_ORDER_ATTRIBUTES. Provides `process_order`, `process_refund`, `find_or_create_offer/sku/product`.

### BazaarEtl (Primary, 1400+ lines)

Processes Bazaar e-commerce orders:
- `pull_and_process_orders` - Batch order ETL with filtering (id range, date, status, type, source)
- `pull_and_process_reviews` - Review ETL
- `pull_and_process_subscriptions_updates` - Subscription status sync
- Supports affiliate tracking via Refersion and Everflow

### AmazonEtl (900+ lines)

Processes Amazon Seller Central orders across 12 marketplaces (US, CA, ES, GB, FR, DE, IT, BR, IN, CN, JP, AU). Handles multi-currency conversion, settlements, and refunds via MWS API.

### BunyanEtl (600+ lines)

Processes event tracking data from bunyan_events/bunyan_clients tables. Handles upsell impression tracking (offered, accepted, purchased).

### Other ETL Services

- **`FacebookEtl`** - Facebook Ads insights (spend, clicks, actions)
- **`GoogleAdsEtl`** - Google Ads campaigns via OAuth2
- **`ShopifyEtl`** - Shopify orders via REST API
- **`SpAmazonEtl`** - Amazon Selling Partner API (newer than MWS)
- **`GoogleAnalyticsReportingService`** - GA4 integration

## Controllers

- **`ReportsController`** - Dynamic report rendering (JSON/HTML/CSV). `show` action loads report class from parameter, validates subclass of Report.

## Configuration

```ruby
Aristotle.configure do |config|
  config.internal_hosts = [...]
  config.order_data_sources = [...]
end
```

Engine autoloads `app/reports` directory for custom Report subclasses.

## Key Patterns

1. **Denormalization** - Transaction items contain order header attributes for query performance
2. **Numeric Precision** - All monetary values stored as integers (cents)
3. **Timestamp Standardization** - All timestamps in UTC
4. **Multi-Source ETL** - Pluggable ETL services for Bazaar, Amazon, Shopify, Facebook, Google
5. **Affiliate Tracking** - Refersion and Everflow commission extraction at transaction level

## Dependencies

- `rails` >= 5.1.4
- `acts-as-taggable-array-on` ~> 0.5.1

## Database

All tables prefixed with `aristotle_`. Uses polymorphic references to source systems (`data_src`, `src_*_id`).
