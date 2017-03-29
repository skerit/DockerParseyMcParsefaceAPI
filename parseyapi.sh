# Use with this Dockerfile https://gist.github.com/johndpope/d41a7d6daf8652cbdaff41a2b063c801

# https://github.com/dsindex/syntaxnet/blob/master/README_api.md
cd /
git clone https://github.com/dsindex/syntaxnet.git work
cd /work
git clone --recurse-submodules https://github.com/tensorflow/serving
# checkout proper version of serving
cd /work/serving
git checkout 89e9dfbea055027bc31878ee8da66b54a701a746
git submodule update --init --recursive
# checkout proper version of tf_models
cd /work/serving/tf_models
git checkout a4b7bb9a5dd2c021edcd3d68d326255c734d0ef0


# apply patch by dmansfield to serving/tf_models/syntaxnet 
cd /work/serving/tf_models
patch -p1 < /work/api/pr250-patch-a4b7bb9a.diff.txt
cd /work

# configure serving/tensorflow
cd /work/serving/tensorflow

# Fix the zlib urls
sed -i -- 's/zlib.net\/zlib/zlib.net\/fossils\/zlib/g' /work/serving/tensorflow/tensorflow/workspace.bzl

# Configure tensorflow
echo "\n\n\n\n" | ./configure
cd /work

# modify serving/tensorflow_serving/workspace.bzl for referencing syntaxnet
cp api/modified_workspace.bzl serving/tensorflow_serving/workspace.bzl
cat api/modified_workspace.bzl

#  ... 
#  native.local_repository(
#    name = "syntaxnet",
#    path = workspace_dir + "/tf_models/syntaxnet",
#  )
#  ...

# append build instructions to serving/tensorflow_serving/example/BUILD
cat api/append_BUILD >> serving/tensorflow_serving/example/BUILD

# copy parsey_api.cc, parsey_api.proto to example directory to build
cp api/parsey_api* serving/tensorflow_serving/example/

# build parsey_api 
cd serving
#disable cuda on osx
bazel clean --expunge && export TF_NEED_CUDA=0 

bazel --output_user_root=bazel_root build --nocheck_visibility -c opt -s //tensorflow_serving/example:parsey_api --genrule_strategy=standalone --spawn_strategy=standalone --verbose_failures --local_resources 2048,.5,1.0

# make softlink for referencing 'syntaxnet/models/parsey_mcparseface/context.pbtxt'
ln -s ./tf_models/syntaxnet/syntaxnet syntaxnet

# run parsey_api with exported model
#./bazel-bin/tensorflow_serving/example/parsey_api --port=9000 ../api/parsey_model