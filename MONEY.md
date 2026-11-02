# Pan Money

How Pan makes money. The company plan is `REVENUE.md` in the Code root; the ledger is `GTM.md`.

## Price and rail

$0.99 upfront on the App Store (ASC 6794988370, store name Curvely), iPhone and Mac. Apple keeps 15%, so each sale pays about $0.84. The web app stays free.

## What is actually sold

The native graphing calculator: equations that persist between launches, PNG export, and the parser and the graph on the device. The code is ours, and nothing sold is someone else's content.

## Who pays and why

A student or engineer who wants a graphing calculator on the phone and the Mac and keeps it once. It runs on the device, so the app costs us nothing to serve per user.

## Cost to serve

No paid API. The math runs on the device. The only server is a stateless evaluate API on Cloudflare Pages Functions, behind an allowlist, with nothing stored. Hosting is Cloudflare's free tier.

## Where we are

- 2026-09-20: price set to $0.99.
- 2026-10-21: renamed to Pan everywhere except the store listing, which still says Curvely (root CLAUDE.md).
- Revenue: no verified number (the App Store Connect key cannot read sales yet).

## Role in the company plan

Catalogue. GTM.md lists it as a $0.99 app that is free on the web. It serves Stage 0 as one more proof that a dollar sells, and under Stage 2 it earns a place on the grid or is retired.

## Next

Once the Sales role is on the App Store Connect key, read the first month of Pan sales. No change until then.

## Million, billion, trillion

**A million.** Pan is the graphing calculator a million students keep, paid once, running on their own device.

**A billion.** Pan is the default calculator on every Jaybulb device, with the math on the machine.

**A trillion.** Pan is the math layer of the platform, with each person's equations kept on their own device.

## Change it

`asc pricing schedule create --app 6794988370 --price 0.99 --base-territory USA --start-date YYYY-MM-DD`. Swap `--price 0.99` for `--free` to revert. No build, no review. Only with Joshua's yes in chat.

Anyone who got Pan while it was free keeps it free.

*ASC 6794988370. Verified 2026-11-02.*
