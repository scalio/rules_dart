# Copyright 2016 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load(":common.bzl", "package_spec_action")
load(
    "//dart/build_rules/common:context.bzl",
    "make_dart_context",
)
load(":dart_vm_snapshot.bzl", "dart_vm_snapshot_action")

def _dart_vm_binary_action(
        ctx,
        script_file,
        srcs,
        deps,
        data = [],
        snapshot = True,
        script_args = [],
        generated_srcs = [],
        vm_flags = [],
        pub_pkg_name = ""):
    dart_ctx = make_dart_context(
        ctx,
        srcs = srcs,
        generated_srcs = generated_srcs,
        data = data,
        deps = deps,
        package = pub_pkg_name,
    )

    if snapshot:
        out_snapshot = ctx.actions.declare_file(ctx.label.name + ".snapshot")
        dart_vm_snapshot_action(
            ctx = ctx,
            dart_ctx = dart_ctx,
            output = out_snapshot,
            vm_flags = vm_flags,
            script_file = script_file,
            script_args = script_args,
        )
        script_file = out_snapshot

    # Emit package spec.
    package_spec = ctx.actions.declare_file(ctx.label.name + ".packages")
    package_spec_action(
        ctx = ctx,
        dart_ctx = dart_ctx,
        output = package_spec,
    )

   # Compute runfiles.
    runfiles_files = dart_ctx.transitive_data.files + [
        ctx.executable._dart_vm,
        ctx.outputs.executable,
        package_spec,
    ]
    
    # Emit entrypoint script.
    if ctx.attr.is_windows:
        sh_templ_output = ctx.actions.declare_file(ctx.label.name + ".sh")
        runfiles_files += [sh_templ_output]
        ctx.template_action(
            output = ctx.outputs.executable,
            template = ctx.file._entrypoint_bat_template,
            executable = True,
            substitutions = {
                "%sh_file%": sh_templ_output.path.replace("/", "\\"),
            },
        )
    else:
        sh_templ_output = ctx.outputs.executable

    ctx.template_action(
        output = sh_templ_output,
        template = ctx.file._entrypoint_template,
        executable = True,
        substitutions = {
            "%workspace%": ctx.workspace_name,
            "%dart_vm%": ctx.executable._dart_vm.path,
            "%package_spec%": package_spec.path,
            "%vm_flags%": " ".join(vm_flags),
            "%script_file%": script_file.path,
            "%script_args%": " ".join(script_args),
        },
    )

    if snapshot:
        runfiles_files += [out_snapshot]
    else:
        runfiles_files += dart_ctx.transitive_srcs.files

    return ctx.runfiles(
        files = list(runfiles_files),
        collect_data = True,
    )

_default_binary_attrs = {
    "_dart_vm": attr.label(
        allow_single_file = True,
        executable = True,
        cfg = "host",
        default = "@dart_sdk//:dart_vm",
    ),
    "_entrypoint_template": attr.label(
        allow_single_file = True,
        default = "//dart/build_rules/templates:dart_vm_binary.sh",
    ),
    "_entrypoint_bat_template": attr.label(
        allow_single_file = True,
        default = "//dart/build_rules/templates:dart_vm_binary.bat",
    ),
    "is_windows": attr.bool(mandatory = True),
}

internal_dart_vm = struct(
    binary_action = _dart_vm_binary_action,
    common_attrs = _default_binary_attrs,
)
