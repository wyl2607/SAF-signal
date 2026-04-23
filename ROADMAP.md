# Roadmap

> This is a public-facing roadmap. For detailed development plans, see internal project tracking.

---

## Now — Live

- Real-time 7-metric market snapshot (Brent, Jet EU, Rotterdam, EU ETS, Germany premium, carbon proxy)
- Multi-source fallback chain with confidence tracking
- Interactive price-trend charts (1d / 7d / 30d)
- i18n support (English / Deutsch / 中文)
- Docker-based deployment
- PostgreSQL / SQLite dual-write migration path

## Near-term

### Production Hardening
- HTTPS / TLS termination
- CI/CD pipeline (GitHub Actions)
- Dependency vulnerability scanning
- API rate limiting

### Real SAF Price Integration
- Integrate live SAF market prices from certified data providers
- SAF-vs-fossil break-even calculator
- Procurement timing signals

### Alerting & Notifications
- User-configurable price thresholds
- Email and Slack alerts when metrics cross thresholds
- Daily / weekly digest reports

## Mid-term

### Decision Support Engine
- "Buy / Hold / Wait" recommendations based on market conditions
- Scenario comparison tools
- Exportable PDF procurement briefs

### Performance & Scale
- Redis caching layer
- CDN for global static asset delivery
- PostgreSQL read replicas

### User Management
- OAuth login (Google, GitHub)
- API key access for programmatic integrations
- Role-based permissions

## Long-term

- Mobile-responsive PWA
- Additional regional markets (APAC, North America)
- Integration with airline ERP / procurement systems
- Historical backtesting of procurement strategies

---

*Last updated: 2026-04-23*
