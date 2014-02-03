# Siteomatic
#### Automatic website deployment
Jonas Acres, jonas@becuddle.com

### What does it do?
Siteomatic automatically deploys static websites to Amazon S3 based on a Github webhook. Sites are bucketed by branch, and domains are managed in Amazon Route 53. For example, you might be working on dev.example.com, and you have just pushed a branch called "reskin-buttons". Siteomatic will create a "reskin-buttons.dev.example.com" domain if it doesn't exist yet, point to Amazon S3, and sync the contents of your branch into the bucket so you have a public link to the site instantly.

### Why would I want to do that?
Sharing work is time-consuming and annoying, but essential to collaboration. It is time-consuming and tedious to simply FTP the latest changes into place whenver someone wants to view them, and in a branched development model, this may not even be possible. Siteomatic lets everyone deploy branched work with zero effort.

### I'm going to have a zillion S3 buckets and Route 53 domains if I do this. Will this be expensive?
Nope! Amazon charges by utilization, not number of buckets or record sets. A small business with a moderately sized website will probably do under $3/mo. in AWS fees by running Siteomatic. This is far less than the value of the time developers spend doing manual deployments.

### What do I need to run this?
* A Github repository for your site
* An Amazon AWS account
* An Amazon Route 53 zone configured for the domain you intend to deploy to
* AWS API key and secret with permissions to manage S3 buckets (All Actions) and Route 53 zones (ChangeResourceRecordSets, GetChange, GetHostedZone, ListHostedZones, ListResourceRecordSets)
* A server where you can run Siteomatic and receive HTTP traffic from Github

### How do I get started?
