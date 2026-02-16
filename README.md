# Aristotle

An analytics ETL and data warehouse engine for Rails. Extracts, transforms, and loads e-commerce transaction data from multiple sources into a read-only analytics database for reporting.

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.

## Features

- Multi-source ETL: Bazaar (primary), Amazon Seller Central, Shopify
- Marketing spend ingestion: Facebook Ads, Google Ads
- Event tracking integration via Bunyan
- 29 analytics models covering transactions, products, customers, marketing, and experiments
- Dynamic report system with JSON/HTML/CSV export
- Multi-currency support with historical exchange rates
- Affiliate/channel partner commission tracking (Refersion, Everflow)
- Upsell impression and conversion tracking
- Coupon usage analytics

## Models Overview

| Model | Purpose |
|-------|---------|
| `TransactionItem` / `TransactionSku` | Line-item analytics (primary query target) |
| `Order` | Order header data |
| `Subscription` | Recurring subscription tracking |
| `Product` / `Offer` / `Sku` | Product catalog |
| `Customer` | End-user data |
| `ChannelPartner` | Affiliate/reseller tracking |
| `MarketingSpend` | Daily marketing spend metrics |
| `Experiment` / `ExperimentVariant` | A/B test data |
| `CurrencyExchange` | Historical exchange rates |
| `Report` | Abstract base for custom reports |

## ETL Services

| Service | Source |
|---------|--------|
| `BazaarEtl` | Bazaar e-commerce orders (primary) |
| `AmazonEtl` | Amazon Seller Central (12 marketplaces) |
| `ShopifyEtl` | Shopify REST API |
| `BunyanEtl` | Event tracking data |
| `FacebookEtl` | Facebook Ads insights |
| `GoogleAdsEtl` | Google Ads campaigns |

## Dependencies

- `rails` >= 5.1.4
- `acts-as-taggable-array-on` ~> 0.5.1

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
