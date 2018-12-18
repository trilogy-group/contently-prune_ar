# prune_ar

[![CircleCI](https://circleci.com/gh/contently/prune_ar.svg?style=shield)](https://circleci.com/gh/contently/prune_ar)

prune_ar is a gem that prunes database records using passed in deletion criteria & then pruning all subsequently orphaned records. It uses ActiveRecord's `belongs_to` associations in order to find orphaned records. It's main intent is to be able to delete any sets of records you would like to but also making sure that the database is left in a consistent state after the deletion (no orphaned records & no violated foreign key constraints). A side effect of pruning the orphaned records (done for consistency) is that it can be effectively used to prune down the whole database at once by issuing a delete on a top level table. Contently uses this process to prune down its production database down to one that is suitable for use in development (devoid of customer data).

The APIs provided are **destructive** to your database, so don't run this in production.

## Getting Started
### Prerequisites
##### Production
No non-gem dependencies.

##### Development & testing
Make sure to have [sqlite3](https://www.sqlite.org/index.html) installed so you can run the tests.

### Support

#### Database

The gem **should** work with any database since it uses either generic SQL or abstractions through `ActiveRecord` that should all be general. Sadly, since different databases sometimes have very different behaviors and quirks, one would expect things to possibly break on some databases. These are the databases the gem is tested against & what level of testing is done against them:

Database | Level of testing (confidence of success)
--- | ---
PostgreSQL 9.4 | Unit tests & real world workload
PostgreSQL 10 | Unit tests & real world workload
PostgreSQL 11 | Unit tests
MySQL 5 | Unit tests
MySQL 8 | Unit tests
MariaDB 5 | Unit tests
MariaDB 10 | Unit tests
SQLite 3 | Unit tests

So we certainly have the highest confidence for success with PostgreSQL since we've actually tested the code against a real database. Please let us know your experience (& any issues you face) with this gem when used with your database type.

If you use this gem with MySQL (or others with similar behavior), you may want to turn off the sanity checking (which creates foreign key constraints). From my small knowledge of MySQL, I believe it creates an index (if one doesn't exist) when a foreign key constraint is created. The gem does not make any effort to clean up these indexes when the foreign key constraints are deleted. It is possible that MySQL will auto-delete them? (but I'm not sure).

#### ActiveRecord

This gem is known to work with ActiveRecord 5.x but the version has not been fixed in the gemspec to allow you to try it out with other versions of ActiveRecord (where it may well work fine or may not).

### Installation & usage

For bundler, add this to your `Gemfile`:

```ruby
gem "prune_ar", "~> 0.1"
```

followed by

```sh
bundle install
```

You can also just install the gem without bundler with

```sh
gem install prune_ar
```

#### Usage

Basic example:

```ruby
require 'prune_ar'
deletion_criteria = { Account => ["accounts.internal = 'f'"] }
Rails.application.eager_load! # We do this to make sure all models are loaded
PruneAr::prune_all_models(deletion_criteria: deletion_criteria)
```

This will delete all external `Account`s & any child records that have an upward dependency chain (unlimited number of hops) to those deleted records. If a table does **not** have an upward dependency chain to the `Account` table, it will remain untouched.

One API is provided: `PruneAr::prune_all_models`. `prune_all_models` gathers all models in your application by looking at the descendants of `ActiveRecord::Base` so it is vital that you make sure all your `ActiveRecord` models are loaded before you call this. The models gathered here are the only ones that `PruneAr` will prune orphaned records from so if only a subset of your applications models are loaded (& seen by `PruneAr`) your database could be left in an inconsistent (referential integrity wise) state after pruning or be blocked from pruning by foreign keys constraints on tables untracked by `PruneAr`.

Here's a brief description of what the main parameters to these APIs mean:

---

##### :deletion_criteria
The core pruning criteria that you want to execute (will be executed up front)
```ruby
deletion_criteria: {
  Account => ['accounts.id NOT IN (1, 2)']
  User => ["users.internal = 'f'", "users.active = 'f'"]
}
```

---

##### :full_delete_models
Models for which you want to purge all records
```ruby
full_delete_models: [Model1, Model2]
```

---

##### :pre_queries_to_run
Arbitrary SQL statements to execute before pruning
```ruby
pre_queries_to_run: ['UPDATE users SET invited_by_id = NULL WHERE invited_by_id IS NOT NULL']
```

---

##### :conjunctive_deletion_criteria
Pruning criteria you want executed in conjunction with each iteration of pruning of orphaned records (one case where this is useful if pruning entities which don't have a belongs_to chain to the entities we pruned but instead are associated via join tables)
```ruby
conjunctive_deletion_criteria: {
    Image => ['NOT EXISTS (SELECT 1 FROM imagings WHERE imagings.image_id = images.id)']
}
```

---

##### :perform_sanity_check (defaults to true)
Determines whether `PruneAr` sanity checks it's own pruning by setting (& subsequently removing) foreign key constraints for all belongs_to relations. This is to prove that we maintained referential integrity.
```ruby
perform_sanity_check: true
```

---

##### :logger
You can provide your own logger to be used for logging any messages that the API logs
```ruby
logger: Logger.new(STDOUT).tap { |l| l.level = Logger::INFO }
```

---

Here is an example of a rake task that is similar to what Contently uses to prune their database:

```ruby
desc 'Prune tables using prune_ar'
task prune_tables: :no_prod_env do
  Rails.application.eager_load!
  PruneAr::prune_all_models(
    deletion_criteria: {
      Account => ['id NOT IN (589, 87)'],
      User => ["email NOT ILIKE '%@company.com'"]
    },
    # This pre-query makes sure that the users that we want to keep (emails like company.com) are not pruned because they were
    # => invited by another user that doesn't have this email (and hence we've deleted their record)
    pre_queries_to_run: ["UPDATE users SET invited_by_id = NULL WHERE invited_by_id IS NOT NULL"],
    # Since images are referenced via a join table, they do not have a direct upward dependency chain to another entity
    # => so we manually prune them using the query below
    conjunctive_deletion_criteria: {
      Image => ['NOT EXISTS (SELECT 1 FROM imagings WHERE imagings.image_id = images.id)']
    },
    full_delete_models: [Comment],
    logger: Logger.new(STDOUT).tap { |l| l.level = Logger::INFO }
  )
end
```

## Details

The motivation for writing prune_ar came about due to two main things:

- wanting a system to specify easy deletion criteria for a few top level tables & have the whole database be pruned accordingly. One use of this is to take a production database, provide a few high level table deletion criteria & end up with a pruned small clean database to be used for development purposes.
- previous approaches to accomplish the above goal had issues with orphaned records. These orphaned records are fairly harmless on their own, but it creates major issues when one is prevented from adding foreign key constraints to these tables with orphaned records.

prune_ar solves both of these. Here is a high level overview of what the algorithm used in prune_ar does:

1. Gather all `belongs_to` associations for the models given.
2. Drop all foreign key constraints (if the database supports foreign keys). This is done so prune_ar can delete records without hitting foreign key violation errors.
3. Run any queries specified in `pre_queries_to_run`.
4. Run the base deletion provided via `deletion_criteria`.
5. Truncate tables for `full_delete_models`.
6. Prune orphaned records & also delete via `conjunctive_deletion_criteria` alongside.
7. Restore original foreign key constraints (if the database supports foreign keys).

prune_ar handles polymorphic belongs_to & is able to prune [HABTM](https://guides.rubyonrails.org/association_basics.html#the-has-and-belongs-to-many-association) tables in addition simple belongs_to associations.

## Development
### Installation
```sh
gem install bundler
git clone https://github.com/contently/prune_ar.git
cd ./prune_ar
bundle install
```

### Running the tests
Assuming you've followed the steps outlined above for the Development installation, you can run
```sh
bundle exec rspec
```
to execute all tests.

#### Test structure
Each class has it's own `class_name_spec.rb` file in the [spec](spec) directory. The database [schema](spec/support/schema.rb) & [models](spec/support/models.rb) are located in [spec/support](spec/support).

### Coding style
Mostly standard rubocop guidelines are followed with a few modications as can be seen in [.rubocop.yml](.rubocop.yml).

## Deployment
In order to deploy a new version of the gem to rubygems:

- Bump the version in [version.rb](lib/prune_ar/version.rb) as appropriate according to [SemVer](http://semver.org/).
- Commit all changes & merge it to the master branch.
- On latest master (after a `git pull` on master):

```sh
rake build
rake release
```

If all went well, a new version of this gem should be published on rubygems.

## Built With

* [bundler](https://bundler.io/) - Dependency management.
* [activerecord](https://rubygems.org/gems/activerecord) - This gem is based around ActiveRecord models.
* [rspec](https://rubygems.org/gems/rspec) - Testing framework.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/contently/prune_ar/tags).

## Authors

* **Anirban Mukhopadhyay** - *Initial work* - [anirbanmu](https://github.com/anirbanmu)

See also the list of [contributors](https://github.com/contently/prune_ar/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
