#!/usr/bin/env python
"""
Convert /proc/irq/default_smp_affinity from hex to human-readable CPU lists.
"""


def print_range(range_start, last_cpu):
    if range_start == last_cpu:
        return last_cpu
    else:
        return f"{range_start} - {last_cpu}"


def list_representation(cpu_list):
    if len(cpu_list) == 0:
        return []

    out_list = []
    range_start = cpu_list[0]
    last_cpu = cpu_list[0]
    for i in range(1, len(cpu_list)):
        # Iterate until we hit a gap.
        if last_cpu == cpu_list[i] - 1:
            last_cpu = cpu_list[i]
        else:
            out_list.append(print_range(range_start, last_cpu))
            range_start = cpu_list[i]
            last_cpu = cpu_list[i]
        # If we hit a gap, print.
    out_list.append(print_range(range_start, last_cpu))
    return out_list


def hex_to_cpu_lists(hex_affinity):
    x = int(hex_affinity, 16)
    i = 0
    enabled_cpus = []
    disabled_cpus = []

    for i in range(len(hex_affinity) * 4):
        shifted = 1 << i
        if x & shifted != 0:
            enabled_cpus.append(i)
        else:
            disabled_cpus.append(i)

    return enabled_cpus, disabled_cpus


def main():
    affinity_file = "/proc/irq/default_smp_affinity"

    try:
        with open(affinity_file, "r") as f:
            hex_affinity = f.read()

        hex_affinity = hex_affinity.replace(",", "").strip()
        enabled_cpus, disabled_cpus = hex_to_cpu_lists(hex_affinity)

        print(f"enabled: {list_representation(enabled_cpus)}")
        print(f"disabled: {list_representation(disabled_cpus)}")

    except FileNotFoundError:
        print(f"Error: {affinity_file} not found")
    except PermissionError:
        print(f"Error: Permission denied reading {affinity_file}")
    except ValueError as e:
        print(f"Error: Invalid hexadecimal format in {affinity_file}")


if __name__ == "__main__":
    main()
