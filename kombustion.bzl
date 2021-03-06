KombustionFiles = provider(fields = ["manifest", "lock", "plugins", "deps"])

script_template = """\
#!/bin/bash

for i in "$@"
do
case $i in
    --profile=*)
    PROFILE=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`

    ;;
    --environment=*)
    DEPLOY_ENV=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
esac
done

BUILD_FILE="{build_file}"
BUILD_DIR=$(dirname $BUILD_FILE)
SOURCE_FOLDER=$(basename $BUILD_DIR)

STACK_ENV="{default_environment}"
IAM="{iam}"
ACTION="{action}"
MANIFEST_FILE="{manifest_file}"
STACKFILE="{template_file}"
MANIFEST_DIR=$(dirname $MANIFEST_FILE)

# Create the PREFIX
# Create the REALM, which we define as the first two folders in the path.
REALM=
PREFIX=

PATH_ARRAY=$(echo $MANIFEST_DIR | tr "/" "\n")

for FRAGMENT in $PATH_ARRAY
do
    CAPITALISED=$(echo $FRAGMENT | python -c "print raw_input().capitalize()")
    PREFIX=$PREFIX$CAPITALISED
done

# Capture the root dir, so we can refernce the stackfile after we cd to the kombustion
# root location
ROOT=$(pwd)

cd $BUILD_WORKSPACE_DIRECTORY

# Capture the git commit
COMMIT=$(git rev-parse --short HEAD)

cd $MANIFEST_DIR

KOMBUSTION_ARGS=""

if [[ -n $PROFILE ]]; then
  KOMBUSTION_ARGS="$KOMBUSTION_ARGS --profile $PROFILE"
fi

if [[ -n $DEPLOY_ENV ]]; then
  STACK_ENV="$DEPLOY_ENV"
fi

UPSERT_ARGS="--param CommitHash=$COMMIT --param Prefix=$PREFIX --param SourcePath=$BUILD_DIR --param SourceFolder=$SOURCE_FOLDER --tag CommitHash=$COMMIT --tag SourcePath=$BUILD_DIR --tag Environment=$STACK_ENV"

if [[ "True" == "$IAM" ]]; then
  UPSERT_ARGS="$UPSERT_ARGS --iam"
fi

ACTION_ARGS="$ACTION_ARGS --environment $STACK_ENV"

if [[ "upsert" == "$ACTION" ]]; then
  ACTION_ARGS="$ACTION_ARGS $UPSERT_ARGS"

fi

echo "============================================================================"
kombustion --version
echo "----------------------------------------------------------------------------"
echo "Deploying to environment: $STACK_ENV"
echo "----------------------------------------------------------------------------"

echo "kombustion $KOMBUSTION_ARGS $ACTION $ACTION_ARGS $STACKFILE"

# Run kombustion
kombustion $KOMBUSTION_ARGS $ACTION $ACTION_ARGS $ROOT/$STACKFILE
"""

# Creates a new dict with a union of the elements of the arguments
def _add_dicts(*dicts):
    result = {}
    for d in dicts:
        result.update(d)

    return result

# [ Action ]----------------------------------------------------------------------------------------
def _implementation(ctx):
    files = [ctx.executable.resolver]

    for f in ctx.files.templates:
        script_content = script_template.format(
            build_file = ctx.build_file_path,
            manifest_file = ctx.attr.kombustion[KombustionFiles].manifest[0].path,
            template_file = f.path,
            action = ctx.attr.action,
            default_environment = ctx.attr.default_environment,
            iam = ctx.attr.iam,
        )

        script = ctx.actions.declare_file("%s-%s" % (ctx.attr.action, f.short_path))

        ctx.actions.write(script, script_content, is_executable = True)

    runfiles = ctx.runfiles(
        files = ctx.files.templates,
        transitive_files = depset(
            ctx.files.templates,
            transitive = ctx.attr.kombustion[KombustionFiles].deps,
        ),
    )

    return [DefaultInfo(
        executable = script,
        runfiles = runfiles,
    )]

_upsert_kombustion_rule = rule(
    implementation = _implementation,
    attrs = _add_dicts(
        {
            "resolver": attr.label(
                default = Label("//:resolver"),
                cfg = "host",
                executable = True,
                allow_files = True,
            ),
            "templates": attr.label_list(
                mandatory = True,
                doc = "Stack files to be acted upon.",
                allow_files = True,
            ),
            "kombustion": attr.label(),
            "action": attr.string(default = "upsert"),
            "default_environment": attr.string(default = "Development"),
            "iam": attr.bool(default = False, doc = "Sets --capability=iam"),
        },
    ),
    executable = True,
)

_delete_kombustion_rule = rule(
    implementation = _implementation,
    attrs = _add_dicts(
        {
            "resolver": attr.label(
                default = Label("//:resolver"),
                cfg = "host",
                executable = True,
                allow_files = True,
            ),
            "templates": attr.label_list(
                mandatory = True,
                doc = "Stack files to be acted upon.",
                allow_files = True,
            ),
            "kombustion": attr.label(),
            "action": attr.string(default = "delete"),
            "default_environment": attr.string(default = "Development"),
            "iam": attr.bool(default = False, doc = "Sets --capability=iam"),
        },
    ),
    executable = True,
)

_events_kombustion_rule = rule(
    implementation = _implementation,
    attrs = _add_dicts(
        {
            "resolver": attr.label(
                default = Label("//:resolver"),
                cfg = "host",
                executable = True,
                allow_files = True,
            ),
            "templates": attr.label_list(
                mandatory = True,
                doc = "Stack files to be acted upon.",
                allow_files = True,
            ),
            "kombustion": attr.label(),
            "action": attr.string(default = "events"),
            "default_environment": attr.string(default = "Development"),
            "iam": attr.bool(default = False, doc = "Sets --capability=iam"),
        },
    ),
    executable = True,
)

_generate_kombustion_rule = rule(
    implementation = _implementation,
    attrs = _add_dicts(
        {
            "resolver": attr.label(
                default = Label("//:resolver"),
                cfg = "host",
                executable = True,
                allow_files = True,
            ),
            "templates": attr.label_list(
                mandatory = True,
                doc = "Stack files to be acted upon.",
                allow_files = True,
            ),
            "kombustion": attr.label(),
            "action": attr.string(default = "generate"),
            "default_environment": attr.string(default = "Development"),
            "iam": attr.bool(default = False, doc = "Sets --capability=iam"),
        },
    ),
    executable = True,
)

# [ Macro ]-----------------------------------------------------------------------------------------

def kombustion(name, **kwargs):
    """Interact with a collection of K8s objects.
    Args:
      name: name of the rule.
      objects: list of k8s_object rules.
    """
    # Create a rule for each action we can take on a stack

    _upsert_kombustion_rule(name = name, **kwargs)  # the default is implictly upsert
    _upsert_kombustion_rule(name = name + ".upsert", **kwargs)
    _delete_kombustion_rule(name = name + ".delete", **kwargs)
    _events_kombustion_rule(name = name + ".events", **kwargs)
    _generate_kombustion_rule(name = name + ".generate", **kwargs)

# [ Kombustion Library ]----------------------------------------------------------------------------

def _kombustion_library_impl(ctx):
    # TODO: Plugins
    plugins = depset(
        # ctx.attr.plugins,
        # transitive = [],
        # transitive = [ctx.attr.plugins[KombustionFiles].transitive_sources for dep in ctx.attr.plugins],
    )
    lock = depset(
        ctx.files.lock,
        transitive = [plugins],
    )
    deps = depset(
        ctx.files.manifest,
        transitive = [lock],
    )

    return [
        KombustionFiles(
            manifest = ctx.files.manifest,
            lock = ctx.files.lock,
            plugins = plugins,
            deps = [deps],
        ),
        DefaultInfo(files = deps),
    ]

# Provides a library function to gather kombustion specific files
# the manifest, lock and plugins
kombustion_library = rule(
    implementation = _kombustion_library_impl,
    attrs = {
        "manifest": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "lock": attr.label(
            allow_single_file = True,
        ),
        "plugins": attr.label_list(
            allow_files = True,
        ),
    },
)
