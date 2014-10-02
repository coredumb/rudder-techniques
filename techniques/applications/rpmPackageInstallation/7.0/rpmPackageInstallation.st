#####################################################################################
# Copyright 2011-2013 Normation SAS
#####################################################################################
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, Version 3.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#####################################################################################

##########################################################################
# Installs requested packages by OS                                      #
#                                                                        #
# - RPM_PACKAGE_REDLIST --> The OS dependant packages to install         #
#                                                                        #
# - RPM_PACKAGE_REDACTION -->  The action to be made on these packages   #
#                                                                        #
# - RPM_PACKAGE_VERSION -->  The optionnal package version               #
#                                                                        #
##########################################################################

bundle agent check_rpm_package_installation {

    vars:
        &RPM_PACKAGE_CHECK_INTERVAL:{check_interval |"rpm_package_check_interval" string => "&check_interval&";
        }&

        "package_number" int => readstringarrayidx("rpm_data","${sys.workdir}/inputs/rpmPackageInstallation/7.0/rpmPackageInstallationData", "#[^\n]*",":",9000,1600000);
&! We need to use the i0 notation to have indexes starting at 0, as in readstringarrayidx !&

        &RPM_PACKAGE_REDLIST:{name |"rpm_package[&i0&]" string => "&name&";
        }&

        &RPM_PACKAGE_VERSION:{version |"rpm_version[&i0&]" string => "&version&";
        }&

        &RPM_PACKAGE_POST_HOOK_COMMAND:{command |"rpm_command[&i0&]" string => "&command&";
        }&

        "index_rpmpkg" slist => getindices("rpm_package");

    # If the promises have been updated, we need to remove previously
    # defined persistent classes (by setting there persistence to 1 minutes)
    # and cancelling also the classes for this run
    rudder_promises_generated_repaired::
        "zmd_classes_to_cancel_on_update" slist => { "zmd_kept", "zmd_restarted", "could_not_restart_zmd" };

        "unpersist_rpm_kept_classes_${index_rpmpkg}"
            string  => "undefine",
            classes => rudder_always_classes_persist("rpm_package_install_kept_${index_rpmpkg}", "1");

        "rpm_kept_classes_purged_${index_rpmpkg}"
            string  => "undefine",
            classes => cancel_all_classes("rpm_package_install_kept_${index_rpmpkg}");

        "unpersist_rpm_repaired_classes_${index_rpmpkg}"
            string  => "undefine",
            classes => rudder_always_classes_persist("rpm_package_installed_${index_rpmpkg}", "1");

        "rpm_repaired_classes_purged_${index_rpmpkg}"
            string  => "undefine",
            classes => cancel_all_classes("rpm_package_installed_${index_rpmpkg}");

        "unpersist_rpm_error_classes_${index_rpmpkg}"
            string  => "undefine",
            classes => rudder_always_classes_persist("rpm_package_install_failed_${index_rpmpkg}", "1");

        "rpm_error_classes_purged_${index_rpmpkg}"
            string  => "undefine",
            classes => cancel_all_classes("rpm_package_install_failed_${index_rpmpkg}");

        "unpersist_${zmd_classes_to_cancel_on_update}"
            string  => "undefine",
            classes => rudder_always_classes_persist("${zmd_classes_to_cancel_on_update}", "1");

        "${zmd_classes_to_cancel_on_update}_purged"
            string  => "undefine",
            classes => cancel_all_classes("${zmd_classes_to_cancel_on_update}");

    redhat::
        # First export the list of available updates - Yes we are cheating
        "get_update_list"   string => execresult("/usr/bin/yum --quiet check-update > ${sys.workdir}/state/software_updates.csv","useshell"),
            classes     => rudder_common_classes("get_update_list"),
            ifvarclass  => "!get_update_list";

        # Get last version for updates
        "${index_rpmpkg}_update_version" string => execresult("/bin/grep ${rpm_package[${index_rpmpkg}]} ${sys.workdir}/state/software_updates.csv | /bin/awk 'END {print $2}' | /bin/cut -f 2 -d :","useshell"),
            classes     => rudder_common_classes("${index_rpmpkg}_update_check"),
            ifvarclass  => "!(${index_rpmpkg}_update_check_kept|${index_rpmpkg}_update_check_repaired|${index_rpmpkg}_update_check_failed)";

    classes:

        "${index_rpmpkg}_package_version_defined" not => strcmp("${rpm_data[${index_rpmpkg}][1]}", "default");

        # Set a class to run a post hook or not
        &RPM_PACKAGE_POST_HOOK_RUN:{run |"rpm_execute_command_&i0&" expression => strcmp("&run&", "true");
        }&


    packages:

        redhat::
            "${rpm_package[${index_rpmpkg}]}"
                package_policy  => "${rpm_data[${index_rpmpkg}][0]}",
                package_method  => generic_nobulk("30"),
                package_select  => "==",
                package_version => "${${index_rpmpkg}_update_version}",
                classes         => rudder_common_classes_persist("rpm_package_installation_${index_rpmpkg}", "${rpm_package_check_interval}"),
                ifvarclass      => "!${index_rpmpkg}_package_version_defined.!(rpm_package_installation_${index_rpmpkg}_repaired|rpm_package_installation_${index_rpmpkg}_error|rpm_package_installation_${index_rpmpkg}_kept)",
                comment         => "Handling ${rpm_package[${index_rpmpkg}]} using yum_nobulk, policy : ${rpm_data[${index_rpmpkg}][0]}";

        SuSE::
            "${rpm_package[${index_rpmpkg}]}"
                package_policy  => "${rpm_data[${index_rpmpkg}][0]}",
                package_method  => generic_nobulk("30"),
                classes         => rudder_common_classes_persist("rpm_package_installation_${index_rpmpkg}", "${rpm_package_check_interval}"),
                ifvarclass      => "!${index_rpmpkg}_package_version_defined.!(rpm_package_installation_${index_rpmpkg}_repaired|rpm_package_installation_${index_rpmpkg}_error|rpm_package_installation_${index_rpmpkg}_kept)",
                comment         => "Handling ${rpm_package[${index_rpmpkg}]} using yum_nobulk, policy : ${rpm_data[${index_rpmpkg}][0]}";

        redhat|SuSE::
            "${rpm_package[${index_rpmpkg}]}"
                package_policy  => "${rpm_data[${index_rpmpkg}][0]}",
                package_method  => generic_nobulk("30"),
                package_select  => "${rpm_data[${index_rpmpkg}][2]}",
                package_version => "${rpm_version[${index_rpmpkg}]}",
                classes         => rudder_common_classes_persist("rpm_package_installation_${index_rpmpkg}", "${rpm_package_check_interval}"),
                ifvarclass      => "${index_rpmpkg}_package_version_defined.!(rpm_package_installation_${index_rpmpkg}_repaired|rpm_package_installation_${index_rpmpkg}_error|rpm_package_installation_${index_rpmpkg}_kept)",
                comment         => "Handling ${rpm_package[${index_rpmpkg}]} using yum_nobulk, policy : ${rpm_data[${index_rpmpkg}][0]}";

    processes:

        SuSE_10.!zypper_version_ok::

            "/usr/lib/zmd/zmd.exe"
                restart_class => "zmd_restart";

    commands:

        # Posthook command
        "${rpm_command[${index_rpmpkg}]}"
            contain    => in_shell,
            classes    => if_else("rpm_command_${index_rpmpkg}_run_ok", "rpm_command_${index_rpmpkg}_run_failed"),
            ifvarclass => "rpm_execute_command_${index_rpmpkg}.rpm_package_installation_${index_rpmpkg}_repaired.!(rpm_package_installation_${index_rpmpkg}_error|rpm_package_installation_${index_rpmpkg}_kept)",
            comment    => "Execute the posthook command if a package has been repaired";

        zmd_restart::

            "/etc/init.d/novell-zmd"
                args       => "restart",
                classes    => kept_if_else_persist("zmd_kept", "zmd_restarted", "could_not_restart_zmd", "${rpm_package_check_interval}"),
                ifvarclass => "!(zmd_kept|zmd_restarted|could_not_restart_zmd).!zypper_version_ok",
                comment    => "Restart the ZMD daemon";

    reports:

        redhat|SuSE::

            "@@packageInstallation@@result_repaired@@${rpm_data[${index_rpmpkg}][3]}@@RHEL/CentOS/SuSE packages@@${rpm_package[${index_rpmpkg}]}@@${g.execRun}##${g.uuid}@#Performed repair action for RPM package ${rpm_package[${index_rpmpkg}]} to comply with policy: ${rpm_data[${index_rpmpkg}][0]}"
        ifvarclass => canonify("rpm_package_installation_${index_rpmpkg}_repaired");

            "@@packageInstallation@@result_error@@${rpm_data[${index_rpmpkg}][3]}@@RHEL/CentOS/SuSE packages@@${rpm_package[${index_rpmpkg}]}@@${g.execRun}##${g.uuid}@#Error taking action for RPM package ${rpm_package[${index_rpmpkg}]} with policy: ${rpm_data[${index_rpmpkg}][0]}"
        ifvarclass => canonify("rpm_package_installation_${index_rpmpkg}_error");

            "@@packageInstallation@@result_success@@${rpm_data[${index_rpmpkg}][3]}@@RHEL/CentOS/SuSE packages@@${rpm_package[${index_rpmpkg}]}@@${g.execRun}##${g.uuid}@#No action required for RPM package ${rpm_package[${index_rpmpkg}]} with policy: ${rpm_data[${index_rpmpkg}][0]}"
        ifvarclass => canonify("rpm_package_installation_${index_rpmpkg}_kept");

    #posthook reports
      "@@packageInstallation@@result_success@@${rpm_data[${index_rpmpkg}][3]}@@Post-modification hook@@${rpm_package[${index_rpmpkg}]}@@${g.execRun}##${g.uuid}@#No post-hook command for ${rpm_package[${index_rpmpkg}]} was defined, not executing"
        ifvarclass => "!rpm_execute_command_${index_rpmpkg}";

      "@@packageInstallation@@result_success@@$${rpm_data[${index_rpmpkg}][3]}@@Post-modification hook@@${rpm_package[${index_rpmpkg}]}@@${g.execRun}##${g.uuid}@#${rpm_package[${index_rpmpkg}]} was already in the desired state, so no command was executed"
        ifvarclass => "rpm_package_installation_${index_rpmpkg}_kept.!rpm_package_installation_${index_rpmpkg}_repaired";

      "@@packageInstallation@@result_success@@$${rpm_data[${index_rpmpkg}][3]}@@Post-modification hook@@${rpm_package[${index_rpmpkg}]}@@${g.execRun}##${g.uuid}@#The post-hook command for ${rpm_package[${index_rpmpkg}]} was correctly executed"
        ifvarclass => "rpm_command_${index_rpmpkg}_run_ok";

      "@@packageInstallation@@result_error@@$${rpm_data[${index_rpmpkg}][3]}@@Post-modification hook@@${rpm_package[${index_rpmpkg}]}@@${g.execRun}##${g.uuid}@#The post-hook command for ${rpm_package[${index_rpmpkg}]} couldn't be executed"
        ifvarclass => "rpm_command_${index_rpmpkg}_run_failed";

    # ZMD Process presence related reports
    (redhat|SuSE).!(SuSE_10.!zypper_version_ok)::
      "@@packageInstallation@@result_success@@${rpm_data[${index_rpmpkg}][3]}@@ZMD process@@None@@${g.execRun}##${g.uuid}@#ZMD process presence verification not necessary. Skipping ...";

    (redhat|SuSE).SuSE_10.!zmd_restart.!zypper_version_ok::
      "@@packageInstallation@@result_success@@${rpm_data[${index_rpmpkg}][3]}@@ZMD process@@None@@${g.execRun}##${g.uuid}@#The ZMD process is present. Skipping ...";

    (redhat|SuSE).SuSE_10.zmd_restarted.!zypper_version_ok::
      "@@packageInstallation@@result_repaired@@${rpm_data[${index_rpmpkg}][3]}@@ZMD process@@None@@${g.execRun}##${g.uuid}@#The ZMD daemon was successfully restarted";

    (redhat|SuSE).SuSE_10.could_not_restart_zmd.!zypper_version_ok::
      "@@packageInstallation@@result_error@@${rpm_data[${index_rpmpkg}][3]}@@ZMD process@@None@@${g.execRun}##${g.uuid}@#The ZMD daemon failed to restart";

}

body package_method generic_nobulk(rpm_pkg_timeout) {

    any::

        # make correct version comparisons
        package_version_less_command  => "${rudder_rpm_knowledge.rpm_compare_less}";
        package_version_equal_command => "${rudder_rpm_knowledge.rpm_compare_equal}";

        package_changes               => "individual";

    redhat::

        package_list_command          => "/bin/rpm -qa --qf '%{name} %{version}-%{release} %{arch}\n'";
        package_list_update_command   => "/usr/bin/yum --quiet check-update";

        package_list_name_regex       => "^(\S+?)\s\S+?\s\S+$";
        package_list_version_regex    => "^\S+?\s(\S+?)\s\S+$";
        package_list_arch_regex       => "^\S+?\s\S+?\s(\S+)$";

        package_installed_regex       => ".*";
        package_name_convention       => "${name}-${version}";
        package_list_update_ifelapsed => "${rpm_pkg_timeout}";
        package_add_command           => "/usr/bin/yum -y install";
        package_delete_command        => "/usr/bin/yum -y remove";
        package_update_command        => "/usr/bin/yum -y update";
        package_verify_command        => "/bin/rpm -V";

    zypper_version_ok::

        package_list_command          => "/bin/rpm -qa --queryformat \"i | repos | %{name} | %{version}-%{release} | %{arch}\n\"";
        package_list_update_ifelapsed => "${rpm_pkg_timeout}";
        package_installed_regex       => "i.*";
        package_list_name_regex       => "[^|]+\|[^|]+\|\s+([^\s]+).*";
        package_list_version_regex    => "[^|]+\|[^|]+\|[^|]+\|\s+([^\s]+).*";
        package_list_arch_regex       => "[^|]+\|[^|]+\|[^|]+\|[^|]+\|\s+([^\s]+).*";
        package_name_convention       => "${name}";
        package_add_command           => "/usr/bin/zypper --non-interactive install";
        package_delete_command        => "/usr/bin/zypper --non-interactive remove --force-resolution";
        package_update_command        => "/usr/bin/zypper --non-interactive update";
        package_verify_command        => "/usr/bin/zypper --non-interactive verify$";

    SuSE_10.!zypper_version_ok::

        package_list_command          => "/bin/rpm -qa --queryformat \"i | repos | %{name} | %{version}-%{release} | %{arch}\n\"";
        package_list_update_ifelapsed => "${rpm_pkg_timeout}";
        package_installed_regex       => "i.*";
        package_list_name_regex       => "[^|]+\|[^|]+\|\s+([^\s]+).*";
        package_list_version_regex    => "[^|]+\|[^|]+\|[^|]+\|\s+([^\s]+).*";
        package_list_arch_regex       => "[^|]+\|[^|]+\|[^|]+\|[^|]+\|\s+([^\s]+).*";

        package_name_convention       => "${name}";
        package_add_command           => "/usr/bin/rug install -y";
        package_delete_command        => "/usr/bin/rug remove -y";
        package_update_command        => "/usr/bin/rug update -y";

        package_verify_command        => "/usr/bin/rug verify -y$"; # $ means no args

}
