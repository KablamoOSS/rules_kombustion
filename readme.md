# Bazel rules for Kombustion

## Requirements

Currently this presumes you have
[Kombustion](https://github.com/KablamoOSS/kombustion) and the AWS cli on your
system.

# Getting Started

Add the following to your `WORKSPACE`

```
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "io_bazel_rules_kombustion",
    # Check to ensure you have the latest/desired commit
    commit = "ab368b8c53f6f699bd9a3a15d85752d83180ee05",
    remote = "https://github.com/KablamoOSS/rules_kombustion.git",
)
```

Next, you need to initalise
[Kombustion](https://github.com/KablamoOSS/kombustion). This can be done
anywhere in your repo. Lets assume the following folder structure.

```
.
├── WORKSPACE
├── readme.md
└── src                                     # Source Code
    ├── jupiter                             # Realm: jupiter
    │   └── infrastructure                  # Domain: infrastructure
    │       ├── BUILD                       # Infrastructure build file
    │       ├── LambdaStorageStack.yaml     # Lambda S3 Bucket stack
    │       └── kombustion.yaml             # Kombustion manifest file
    └── mars                                # Realm: mars
        └── pipeline                        # Domain: pipeline
            ├── BUILD                       # BUILD file to create a target for kombustion.yaml
            ├── kombustion.yaml             # manifest file for mars/pipeline
            ├── stepOne                     # lambda
            │   ├── BUILD                   # lambda build file
            │   ├── StepOneStack.yaml       # lambda CloudFormation stack
            │   └── src                     # lambda source
            │       └── lambda.py
```

### Setup Kombustion

In this case, Kombustion has been initalised at `./src/jupiter/infrastructure`
and `./src/mars/pipeline/`, as evidenced by the presence of a manifest file
`kombustion.yaml`.

If you have any plugins installed, they should be located relative to their
manifest file.

So that we can use our Kombustion manifests we need to create a Bazel target for
them. In the same folder as your `kombustion.yaml`, create a `BUILD` file with
the following:

```
# We want this package to be visible
package(default_visibility = ["//visibility:public"])

# Load the Kombustion rules
load("@io_bazel_rules_kombustion//:kombustion.bzl", "kombustion_library")

# Export the kombustion config
kombustion_library(
    name = "kombustion",
    # Relative path to the manifest
    manifest = "kombustion.yaml",
    # If you have any plugins installed, uncomment the following so they can be used.
    # lock = "kombustion.lock",
    # plugins = glob([
    #     ".kombustion/**",
    # ]),
)
```

Now we have a Kombustion manifest to reference, we can create a `BUILD` file for
our CloudFormation templates.

### Setup a CloudFormation Template

To setup template create a `BUILD` file in the same folder and add the
following, in this case at `src/mars/pipeline/stepOne/BUILD`:

```
load("@io_bazel_rules_kombustion//:kombustion.bzl", "kombustion")

# Create a run target for our template
kombustion(
    name = "deploy",
    # Set this to true to add `--capabilities=iam` or omit to not add it
    iam = True,
    # Bazel path to the kombustion manifest we want to use
    kombustion = "//src/mars/pipeline:kombustion",
    # Relative path to template, can be a glob of multiple templates
    templates = ["StepOneStack.yaml"],
)
```

For every `kombustion` target you create, we also make an `.upsert`, `.delete`,
`.events`, `.generate` target.

So for the example above, you could run any of the following:

```
# the target name is implicity upsert
bazel run //src/mars/pipeline/stepOne:deploy

# To upsert this template:
bazel run //src/mars/pipeline/stepOne:deploy.upsert

# To delete this template:
bazel run //src/mars/pipeline/stepOne:deploy.delete

# To show events for this template:
bazel run //src/mars/pipeline/stepOne:deploy.events

# To generate this template:
bazel run //src/mars/pipeline/stepOne:deploy.generate
```

### `--profile`

By default Kombustion will attempt to use the normal AWS SDK credential chain.
In CI this is likely fine, but running on your own machine this can be
problematic when you have many AWS accounts.

To make this easier you can pass a profile as follows:

```
bazel run //src/mars/pipeline/stepOne:deploy -- --profile myProfileName
```

### `--environment`

By default `--environment Development` will be passed, but this can be
overridden by passing in a flag as follows:

```
bazel run //src/mars/pipeline/stepOne:deploy -- --environment Production
```
