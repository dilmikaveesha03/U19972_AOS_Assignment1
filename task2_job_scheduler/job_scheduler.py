#!/usr/bin/env python3

# University HPC Job Scheduling System

import os
import sys
import time
import datetime
from collections import deque
from typing import TypedDict

class Job(TypedDict):
    student_id:     str
    job_name:       str
    execution_time: int
    priority:       int


class RuntimeJob(TypedDict):
    student_id: str
    job_name:   str
    remaining:  int
    priority:   int

SCRIPT_DIR: str = os.path.dirname(os.path.abspath(__file__))
BASE_DIR:   str = os.path.dirname(SCRIPT_DIR)

JOB_QUEUE_FILE: str = os.path.join(SCRIPT_DIR, "job_queue.txt")
COMPLETED_FILE: str = os.path.join(SCRIPT_DIR, "completed_jobs.txt")
SCHEDULER_LOG:  str = os.path.join(BASE_DIR, "logs", "scheduler_log.txt")

TIME_QUANTUM: int = 5

def log_event(
    student_id:      str,
    job_name:        str,
    scheduling_type: str,
    result:          str
) -> None:
    timestamp: str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    entry: str = (
        f"[{timestamp}] "
        f"StudentID: {student_id} | "
        f"Job: {job_name} | "
        f"Scheduler: {scheduling_type} | "
        f"Result: {result}\n"
    )
    os.makedirs(os.path.dirname(SCHEDULER_LOG), exist_ok=True)
    with open(SCHEDULER_LOG, "a") as log_file:
        log_file.write(entry)


def print_header(title: str) -> None:
    print("\n" + "=" * 60)
    print(f"  {title}")
    print("=" * 60)


def pause() -> None:
    input("\n  Press [Enter] to return to the main menu...")

def load_jobs(filepath: str) -> list[Job]:
    jobs: list[Job] = []
    if not os.path.exists(filepath):
        return jobs

    with open(filepath, "r") as f:
        for line_number, raw_line in enumerate(f, start=1):
            line: str = raw_line.strip()
            if not line or line.startswith("#"):
                continue  # Skip blank lines and comments

            parts: list[str] = [p.strip() for p in line.split("|")]
            if len(parts) != 4:
                print(f"  [WARN] Skipping malformed line {line_number}: {line}")
                continue

            try:
                job: Job = Job(
                    student_id=parts[0],
                    job_name=parts[1],
                    execution_time=int(parts[2]),
                    priority=int(parts[3]),
                )
                jobs.append(job)
            except ValueError:
                print(f"  [WARN] Non-numeric field on line {line_number}: {line}")

    return jobs


def save_jobs(filepath: str, jobs: list[Job]) -> None:
    """Overwrite the job file with the current job list."""
    with open(filepath, "w") as f:
        for job in jobs:
            f.write(
                f"{job['student_id']} | "
                f"{job['job_name']} | "
                f"{job['execution_time']} | "
                f"{job['priority']}\n"
            )


def append_completed_job(job: RuntimeJob, scheduling_type: str) -> None:
    timestamp: str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    os.makedirs(os.path.dirname(COMPLETED_FILE), exist_ok=True)
    with open(COMPLETED_FILE, "a") as f:
        f.write(
            f"{job['student_id']} | "
            f"{job['job_name']} | "
            f"Scheduled: {scheduling_type} | "
            f"Completed: {timestamp}\n"
        )


# View Pending Jobs

def view_pending_jobs() -> None:
    print_header("Pending Jobs")
    jobs: list[Job] = load_jobs(JOB_QUEUE_FILE)

    if not jobs:
        print("\n  No jobs currently in the queue.")
    else:
        print(
            f"\n  {'#':<4} {'StudentID':<12} {'JobName':<20} "
            f"{'ExecTime(s)':<13} {'Priority'}"
        )
        print("  " + "-" * 55)
        for idx, job in enumerate(jobs, start=1):
            print(
                f"  {idx:<4} {job['student_id']:<12} {job['job_name']:<20} "
                f"{job['execution_time']:<13} {job['priority']}"
            )

    log_event("SYSTEM", "VIEW_QUEUE", "N/A", f"{len(jobs)} pending job(s) displayed")
    pause()


# Submit Job

def submit_job() -> None:
    print_header("Submit New Job")

    # Student ID 
    student_id: str = input("\n  Enter Student ID (e.g. IT2024): ").strip()
    if not student_id:
        print("  [ERROR] Student ID cannot be empty.")
        pause()
        return

    # Job Name
    job_name: str = input("  Enter Job Name (e.g. DataAnalysis): ").strip()
    if not job_name:
        print("  [ERROR] Job name cannot be empty.")
        pause()
        return

    # Execution Time 
    exec_time: int
    try:
        exec_time = int(input("  Enter Estimated Execution Time (seconds): ").strip())
        if exec_time <= 0:
            raise ValueError
    except ValueError:
        print("  [ERROR] Execution time must be a positive integer.")
        pause()
        return

    # Priority 
    priority: int
    try:
        priority = int(input("  Enter Priority (1 = lowest, 10 = highest): ").strip())
        if not (1 <= priority <= 10):
            raise ValueError
    except ValueError:
        print("  [ERROR] Priority must be an integer between 1 and 10.")
        pause()
        return

    # Build and save the new job
    job: Job = Job(
        student_id=student_id,
        job_name=job_name,
        execution_time=exec_time,
        priority=priority,
    )
    jobs: list[Job] = load_jobs(JOB_QUEUE_FILE)
    jobs.append(job)
    save_jobs(JOB_QUEUE_FILE, jobs)

    print(f"\n  [SUCCESS] Job '{job_name}' submitted for Student {student_id}.")
    log_event(student_id, job_name, "SUBMISSION", "Job added to queue")
    pause()


# Round Robin Scheduling 

def run_round_robin() -> None:
    print_header("Round Robin Scheduler (Quantum = 5s)")

    jobs: list[Job] = load_jobs(JOB_QUEUE_FILE)
    if not jobs:
        print("\n  [INFO] No jobs in queue to schedule.")
        pause()
        return

    # Convert Job entries into RuntimeJob entries that track remaining time
    runtime_entries: list[RuntimeJob] = [
        RuntimeJob(
            student_id=str(j["student_id"]),
            job_name=str(j["job_name"]),
            remaining=int(j["execution_time"]),
            priority=int(j["priority"]),
        )
        for j in jobs
    ]

    queue:     deque[RuntimeJob] = deque(runtime_entries)
    completed: list[RuntimeJob]  = []
    cycle:     int               = 1

    print(f"\n  Scheduling {len(queue)} job(s) using Round Robin (quantum = {TIME_QUANTUM}s)\n")
    print(f"  {'Cycle':<6} {'StudentID':<12} {'Job':<20} {'Processed(s)':<14} {'Remaining(s)'}")
    print("  " + "-" * 65)

    while queue:
        job:          RuntimeJob = queue.popleft()
        process_time: int        = min(TIME_QUANTUM, job["remaining"])
        job["remaining"]        -= process_time

        print(
            f"  {cycle:<6} {job['student_id']:<12} {job['job_name']:<20} "
            f"{process_time:<14} {job['remaining']}"
        )
        log_event(
            job["student_id"],
            job["job_name"],
            "RoundRobin",
            f"Processed {process_time}s | Remaining: {job['remaining']}s"
        )

        if job["remaining"] > 0:
            queue.append(job)       
        else:
            completed.append(job)
            append_completed_job(job, "RoundRobin")
            log_event(job["student_id"], job["job_name"], "RoundRobin", "COMPLETED")
            print(f"  {'':6} >>> Job '{job['job_name']}' COMPLETED <<<")

        cycle += 1

    save_jobs(JOB_QUEUE_FILE, [])
    print(f"\n  [DONE] All {len(completed)} job(s) completed via Round Robin.")
    pause()


# Priority Scheduling

def run_priority_scheduling() -> None:
    print_header("Priority Scheduler (Highest Priority First)")

    jobs: list[Job] = load_jobs(JOB_QUEUE_FILE)
    if not jobs:
        print("\n  [INFO] No jobs in queue to schedule.")
        pause()
        return
    
    sorted_jobs: list[Job] = sorted(
        jobs,
        key=lambda j: j["priority"],
        reverse=True
    )

    print(f"\n  Execution order for {len(sorted_jobs)} job(s):\n")
    print(f"  {'Order':<7} {'StudentID':<12} {'JobName':<20} {'Priority':<10} {'ExecTime(s)'}")
    print("  " + "-" * 62)

    for order, job in enumerate(sorted_jobs, start=1):
        print(
            f"  {order:<7} {job['student_id']:<12} {job['job_name']:<20} "
            f"{job['priority']:<10} {job['execution_time']}"
        )

    print("\n  Running jobs in priority order...\n")

    for job in sorted_jobs:
        print(
            f"  [RUNNING] {job['job_name']} "
            f"(Priority {job['priority']}, StudentID: {job['student_id']}, "
            f"Time: {job['execution_time']}s)"
        )
        log_event(
            job["student_id"],
            job["job_name"],
            "PriorityScheduling",
            f"Started – Priority {job['priority']}, ExecTime {job['execution_time']}s"
        )

        runtime_job: RuntimeJob = RuntimeJob(
            student_id=job["student_id"],
            job_name=job["job_name"],
            remaining=0,
            priority=job["priority"],
        )
        print(f"  [DONE]    '{job['job_name']}' completed.")
        append_completed_job(runtime_job, "PriorityScheduling")
        log_event(job["student_id"], job["job_name"], "PriorityScheduling", "COMPLETED")

    save_jobs(JOB_QUEUE_FILE, [])
    print(f"\n  [DONE] All {len(sorted_jobs)} job(s) completed via Priority Scheduling.")
    pause()


# Scheduling Sub-Menu 

def run_scheduler() -> None:
    print_header("Run Scheduler – Select Algorithm")
    print("\n  1. Round Robin (Time Quantum = 5s)")
    print("  2. Priority Scheduling (Highest Priority First)")
    print("  3. Back to Main Menu")

    choice: str = input("\n  Select algorithm [1-3]: ").strip()
    if choice == "1":
        run_round_robin()
    elif choice == "2":
        run_priority_scheduling()
    elif choice == "3":
        return
    else:
        print("  [ERROR] Invalid option.")
        time.sleep(1)


# View Completed Jobs

def view_completed_jobs() -> None:
    print_header("Completed Jobs")

    if not os.path.exists(COMPLETED_FILE) or os.path.getsize(COMPLETED_FILE) == 0:
        print("\n  No completed jobs on record.")
    else:
        print()
        with open(COMPLETED_FILE, "r") as f:
            for idx, line in enumerate(f, start=1):
                print(f"  {idx:>3}. {line.rstrip()}")

    log_event("SYSTEM", "VIEW_COMPLETED", "N/A", "Completed jobs list displayed")
    pause()


# Main Menu 

def main_menu() -> None:
    while True:
        os.system("clear")
        print()
        print("  ╔══════════════════════════════════════════════════════════╗")
        print("  ║          University HPC Job Scheduling System            ║")
        print("  ║                                                          ║")
        print("  ╚══════════════════════════════════════════════════════════╝")
        print()
        print("  1. View Pending Jobs")
        print("  2. Submit Job")
        print("  3. Run Scheduler (Round Robin / Priority)")
        print("  4. View Completed Jobs")
        print("  5. Exit")
        print()

        choice: str = input("  Select an option [1-5]: ").strip()

        if choice == "1":
            view_pending_jobs()
        elif choice == "2":
            submit_job()
        elif choice == "3":
            run_scheduler()
        elif choice == "4":
            view_completed_jobs()
        elif choice == "5":
            confirm: str = input(
                "\n  Are you sure you want to exit? (Y/N): "
            ).strip().upper()
            if confirm == "Y":
                log_event("SYSTEM", "EXIT", "N/A", "System exited by user")
                print("\n  Goodbye! HPC Scheduler terminated.\n")
                sys.exit(0)
            else:
                print("  [INFO] Exit cancelled.")
                time.sleep(1)
        else:
            print("  [ERROR] Invalid option. Please choose between 1 and 5.")
            time.sleep(1)


# Entry Point 

if __name__ == "__main__":
    os.makedirs(os.path.dirname(SCHEDULER_LOG), exist_ok=True)
    for filepath in [JOB_QUEUE_FILE, COMPLETED_FILE]:
        if not os.path.exists(filepath):
            open(filepath, "w").close()

    log_event("SYSTEM", "STARTUP", "N/A", "HPC Scheduler initialised")
    main_menu()
