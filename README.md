# Siteomatic
## Automatically push to Amazon S3 static websites based on Github webhook
### Jonas Acres, jonas@becuddle.com

### What does it do?
Siteomatic automatically deploys static websites to Amazon S3 based on a Github webhook. Sites are bucketed by branch, and domains are managed in Amazon Route 53. For example, you might be working on dev.example.com, and you have just pushed a branch called "reskin-buttons". Siteomatic will create a "reskin-buttons.dev.example.com" domain if it doesn't exist yet, point to Amazon S3, and sync the contents of your branch into the bucket so you have a public link to the site instantly.

### Why would I want to do that?
Sharing work is time-consuming and annoying, but essential to collaboration. If your workflow is anything like mine, you have a lot of points in your day where you'd like to pull up your work (or a teammate's work), but don't want to distract anyone by asking them to manually upload the site -- especially if they're working in a branch and you don't want them to overwrite the main development site.

Siteomatic lets everyone deploy branched work with zero effort.

### I'm going to have a zillion S3 buckets and Route 53 domains if I do this. Will this be expensive?
Nope! Route 53's pricing is based entirely on number of hosted zones and millions of queries per month, and not on the number of record sets within those zones. So if you assume this leads to 1 million DNS queries per month ($0.75/mo.), and 1 extra Route 53 zone ($0.50/mo), you'll spend $1.25/mo. on Route 53 with current prices.

S3's pricing is somewhat more complex, but figure that if you store about 10GB per month across all your branches, you're spending about $1.00 to create and store the buckets, and then $0.12/GB to actually serve your clients. If you're doing 2GB/mo. in data transfer, you're spending about $1.24 on S3, for about $2.50/mo. in total cost.

Figure after you pay for payroll taxes and office overhead, a full-time web developer is cheap at $45/hr., so these costs are equivalent to about 3 minutes 20 seconds of a developer's time, which is about how long it takes to manually deploy a site in good conditions. So Siteomatic's AWS utilization pays for itself almost immediately!

### What do I need to run this?
* A Github repository for your site
* An Amazon AWS account
* An Amazon Route 53 zone configured for the domain you intend to deploy to
* AWS API key and secret with permissions to manage S3 buckets (All Actions) and Route 53 zones (ChangeResourceRecordSets, GetChange, GetHostedZone, ListHostedZones, ListResourceRecordSets)
* A server where you can run Siteomatic and receive HTTP traffic from Github

