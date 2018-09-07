script_template = """\
#!/bin/bash


for i in "$@"
do
case $i in
    --profile=*)
    PROFILE=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`

    ;;
    --environment=*)
    STACK_ENV=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
esac


done



BUILD_FILE="{build_file}"
BUILD_DIR=$(dirname $BUILD_FILE)
SRCS="{srcs}"
BUCKET="{bucket}"
NAME="{name}"
BUCKET_KEY=$BUILD_DIR

echo $SRCS

# Capture the root dir, so we can refernce the stackfile after we cd to the kombustion
# root location
ROOT=$(pwd)

cd $BUILD_WORKSPACE_DIRECTORY

# Capture the git commit
COMMIT=$(git rev-parse --short HEAD)

cd $ROOT

LAMBDA_ZIP_FILE="$NAME-$COMMIT.zip"

# -j to strip the leading path
zip -r -9 -j $LAMBDA_ZIP_FILE $SRCS

AWS_CLI_ARGS=""

# If we have a profile we will add it
if [[ -n $PROFILE ]]; then
  AWS_CLI_ARGS="$AWS_CLI_ARGS --profile $PROFILE"
fi

echo "Uploading to s3://$BUCKET/$BUCKET_KEY/$LAMBDA_ZIP_FILE"

aws $AWS_CLI_ARGS s3 cp $LAMBDA_ZIP_FILE s3://$BUCKET/$BUCKET_KEY/$LAMBDA_ZIP_FILE
"""

def _implementation(ctx):
    files = [ctx.executable.resolver]

    script_content = script_template.format(
        build_file = ctx.build_file_path,
        bucket = ctx.attr.bucket,
        name = ctx.attr.name,
        srcs = " ".join([src.path for src in ctx.files.src]),
    )

    script = ctx.actions.declare_file("%s-lambda-upload" % ctx.attr.name)

    ctx.actions.write(script, script_content, is_executable = True)

    runfiles = ctx.runfiles(
        files = ctx.files.src,
    )

    return [DefaultInfo(
        executable = script,
        runfiles = runfiles,
    )]

lambda_upload = rule(
    implementation = _implementation,
    attrs = {
        "resolver": attr.label(
            default = Label("//:resolver"),
            cfg = "host",
            executable = True,
            allow_files = True,
        ),
        "src": attr.label_list(
            mandatory = True,
            doc = "Source folder.",
            allow_files = True,
        ),
        "bucket": attr.string(
            mandatory = True,
        ),
    },
    executable = True,
)
