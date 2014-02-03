# Siteomatic
#### Automatic website deployment
Jonas Acres, jonas@becuddle.com

https://github.com/jonasacres/siteomatic

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
Right now, installation is pretty manual (and is a biggie on the to-do list for this project). Let's assume for sake of discussion that you are installing on a Linux box that already has Ruby installed, and intend to run this as a user named 'siteomatic' whose home directory is at /home/siteomatic.

##### Clone the Siteomatic repo
```
cd
git clone http://github.com/jonasacres/siteomatic
cd siteomatic
bundle install
```

##### Clone your site repo
```
mkdir ~/sites
cd ~/sites
git clone http://github.com/youruser/yoursite
```

You will also need s3cmd. Actually, you'll need two separate versions of it, because the official version doesn't support parallel workers, but the forked version is now out of date and doesn't support static website operations.

##### Clone the s3cmd and s3cmd-modification repos
```
mkdir ~/tools
cd ~/tools
git clone http://github.com/s3tools/s3cmd
git clone http://github.com/cdre/s3cmd-modification
```


##### Create settings.cfg
Now configure siteomatic. There are two configuration files you need to edit: settings.cfg and sites.cfg. As of writing, there is no example file for either in the repository. Bless you for reading the README. Open `~/siteomatic/settings.cfg`:

```
route53_aws_api = AKIAXXXXXXXXXXXXXX
route53_aws_secret = ISDofisd8234JIjsidfSDF2123jA-sdf213
s3_aws_api = AKIAXXXXXXXXXXXXXX
s3_aws_secret = ISDofisd8234JIjsidfSDF2123jA-sdf213
s3cmd = '/home/siteomatic/tools/s3cmd/s3cmd'
s3cmd_parallel = '/home/siteomatic/tools/s3cmd-modification/s3cmd'
s3cmd_parallel_workers = 50
http_port = 3310
```

Set your paths and API keys as appropriate. You can use the same AWS key for Route 53 and S3, or issue different keys, depending on your situation.

`s3cmd_parallel_workers` sets the number of parallel operations that will be allowed to occur during site upload. The default is 30, but you might get better results by tuning it.

`http_port` sets the HTTP port Siteomatic will listen on. The default is 3310.

###### Optional settings.cfg settings

Siteomatic has optional support to send text messages via Twilio when uploads are completed. It will only make use of this functionality if you provide your Twilio API credentials in settings.cfg:
```
twilio_from = +18885551234
twilio_sid = DA1233174747d123d302dabc12309bd23
twilio_auth = 92384adef123ef129bc12ab2
```

Siteomatic also has optional support to send e-mails via Mailgun when uploads are completed. It will only make use of this functionality if you provide your Mailgun API credentials in settings.cfg:
```
mailgun_key = key-2sdf92342ji90834md232
mailgun_domain = example.com
mailgun_from = Siteomatic <siteomatic@example.com>
```

##### Create sites.cfg

Siteomatic will monitor repositories listed in sites.cfg, which is formatted as a JSON array. Each element in this array defines a site, as in the example below:
```
[
	{
		"url":"https://github.com/youruser/yoursite",
		"directory":"/home/siteomatic/sites/yoursite",
		"domain":"dev.yoursite.com",
		"branches":{
			"master":{
				"domain":"www.yoursite.com",
				"email":["you@example.com"],
				"text":["+15035551234"]
			}
		},
		"default":{
		  "email":["you@example.com"]
		}
	}
]
```

Each site has a `url` field which defines the URL for the repo on Github. This URL must match the format supplied in the Github webhook, and so it should follow the format `https://github.com/user/site` exactly. Siteomatic will look in the `directory` directory for the local repository for this site.

When Siteomatic sees an update for a site, it will construct a hostname of the form `{branch}.{domain}`. For example, if the site has `domain = dev.yoursite.com`, and Siteomatic processes a branch named reskin-buttons, it will create `reskin-buttons.dev.yoursite.com` as the domain for the branch. The string is forced to lowercase, non-alphanumeric characters are remapped to hyphen ('-'), consecutive hyphens are transformed into single hyphens, and leading and trailing hyphens are trimmed. So `feature/_magicTest!` will become `feature-magictest.dev.yoursite.com`.

You can override this on a per-branch basis via the `branches` object, which has a key for each branch to be overridden. In this case, the `master` branch is overridden to have the domain `www.yoursite.com`. When overriding a domain, the branch name is NOT prepended to the domain, so `master` will deploy directly to `www.yoursite.com`.

If you have set up optional e-mail or SMS support, you can have Siteomatic notify you when a branch is updated via the `email` and `text` fields, which take an array of e-mail addresses and telephone numbers, respectively. You can set up this notification for non-overridden branches using the `default` object.

##### Run Siteomatic
You're almost done!
```
cd ~/siteomatic
bin/siteomatic settings.cfg sites.cfg
```

If everything went OK, Siteomatic will give oyu output like this:
```
I, [2014-02-03T11:41:59.049642 #55742]  INFO -- : Listening for webhook requests on 3310
== Sinatra/1.4.4 has taken the stage on 3310 for development with backup from Thin
Thin web server (v1.6.1 codename Death Proof)
Maximum connections set to 1024
Listening on 0.0.0.0:3310, CTRL+C to stop
```

As soon as Siteomatic receives a webhook from Github, it will process the repository Github claims it updated.

### Does Siteomatic upload every file of every branch of every repository every time?
No. Siteomatic only processes the repository listed in a Github webhook. When Siteomatic processes a repository, it fetches the latest changes from the Github repository, and then considers each branch (not just the branches in the webhook notification).

When processing a branch, Siteomatic checks the hash of the git commit currently synced into S3 for that branch. This hash is stored as a TXT record in Route 53. If the hash in the repository is different from the hash in the TXT record, or if the TXT record does not exist, Siteomatic uploads the changes to S3 and ensures that the A and TXT records for the domain are current in Route 53.

When uploading changes to S3, Siteomatic does an rsync-style transfer using s3cmd, so only new or changed files are uploaded. Files that exist in the S3 bucket but not in the local repository are deleted from the bucket. s3cmd-modification is used for parallel transfers to dramatically speed up the process.
