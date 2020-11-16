# Salesforce Data Cloner w/ Data Loader

This is dockerised data cloning tool that aims to provide universal data cloning of data between two different salesforce orgs.

This is inspired by [Salesforce Data Loader Docker](https://github.com/shillem/dataloader-docker) by shiilem

## Why this tool is necessary
It is not an easy task to copy data between two orgs. This is because you cannot specify the primary key of the record you are copying. i.e. record ID is decided AFTER you insert a data in salesforce database and is not alterable!

It is that characteristic that makes data migration difficult, because records that reference other records (Look-up and/or Master-Detail field) will have no idea of the external ID until the parent record is inserted AND you cannot predict the ID before you insert it!

So in order to migrate data successfully, you must work out the dependencies of the data first. e.g. If you are migrating Account and Contact, you must:
1. migrate `Account`
1. keep record of the new account records
1. make a map of old id to new id
1. migrate `Contact` converting old `AccountId` to new `AccountId`

This is an arduous task if you have dozens of objects with intricate relationships and certainly not what humans are good at.

This tool is supposed to be a universal tool to automate this process for any arbitrary orgs.

## Requirements
- Docker
- 2 Salesforce orgs that share the same object structure (the objects you are copying must have same structure)
- 2 users with administrative permission on both of the orgs
- `Access Token` and  `Instance URL` of either of the 2 users ([Salesforce CLI](https://developer.salesforce.com/tools/sfdxcli) recommended)


## Methodology
This tool does these things in order. (You need to provide list of objects to the tool!)

1. Get the description of all objects in the list.
1. Resolve the dependencies amonth the list of objects
1. Calculate the order in which to migrate the objects
1. Migrate the data one by one until everything is migrated

## How to get `Access Token` and `Instance URL`

The tools rquires these 2 to get the description of all objects provided. The recommended way to obtain this is using salesforce CLI.

```bash
access_token=$(sfdx force:org:display --verbose --json | jq -r ".result.accessToken")
instance_url=$(sfdx force:org:display --verbose --json | jq -r ".result.instanceUrl")

echo $access_token
echo $instance_url
```


## Creating ID Map for dependant objects that you are not migrating with the tool

In many cases you might choose to migrate some of the object without using this tool. A very common use case is `User`. Users are required in migrating most of the objects because many objects refer to `User` in `OwnerId` field.

However, the tool is not capable of migrating the users, because it is a very complex object. In cases like this you can provide the tool a manually created ID conversion map.

To provide the tool ID conversion maps, create a file that looks like this:

```csv
"OLD_ID","NEW_ID"
"0052v00000USH04AAH","0054x000000ELiFAAW"
"0052v00000cMHjoAAG","0054x000000ELiFAAW"
"0052v00000gXrrpAAC","0054x000000ELiFAAW"
"0052v00000USH26AAH","0054x000000ELiFAAW"
"0052v00000d4BthAAE","0054x000000ELiFAAW"
"0052v00000USGz1AAH","0054x000000ELiFAAW"
```
and place it at `data/conversion_tables/OBJECT_NAME.csv` e.g. `data/conversion_tables/USER.csv`

If you fail to provide the table, the tool will end with exception saying that it failed to convert IDs.

## How?

```bash
# make necessary work folders
mkdir data
chmod 777 data
mkdir configs
chmod 777 configs

# first encrypt the passwords. Replace MYPASSWORD with your password.
# depending on your security setting you might need to append your password with security token.
# repeat this process for source org and destination org
docker container run --rm -v $(pwd)/configs:/opt/app/configs/ --entrypoint dataloader yusukeoshiro/salesforce-dataloader encrypt MYPASSWORD

# take note of the encryption key that looks something like
# fdcc784c3aea04aab9ece579da61d0ce358ffcd01277b6b88b036f487aabf0ed

docker container run --rm -it -v $(pwd)/data:/opt/app/data/ -v $(pwd)/configs:/opt/app/configs/ --entrypoint migrate yusukeoshiro/salesforce-dataloader \
  $instace_url $access_token $objects \
  $source_user_name $source_password \
  $destination_user_name $destination_password \
```

Example command may look something like this.
```bash
docker container run --rm -it -v $(pwd)/data:/opt/app/data/ -v $(pwd)/configs:/opt/app/configs/ \
    --entrypoint migrate d976ff7e0e82 'https://r2-company.my.salesforce.com' '00D7F0000000000!AQIAQMPgfxC2CeEj1OPxsOAFKT2P15jP' \
  'Account,Contact,CustomObject1__c,CustomObject2__c' \
  'yusuke@source.com' 'a358696232e0e9e4471755decf794cea9f37ed83d2276d72576384480115ce77cf5' \
  'yusuke@destination.com' '31416e2c3fbecb05c6e5030e3ac122bb97e64165266e682d30d18aa47c870018' \
```
