AOS Assignment 1 – University Data Centre Management System

1. Project Overview

This project implements three command-line systems for a University Data Centre environment:

Task 1 – Process Manager: monitors system resources, manages processes, inspects disk usage, and detects/archives large log files.

Task 2 – HPC Job Scheduler: manages pending jobs and demonstrates Round Robin and Priority scheduling algorithms.

Task 3 – Secure Submission System: validates assignment submissions, detects duplicate files using SHA-256 hashing, and simulates login security controls.

The project uses Bash for system-management and submission menus and Python 3 for job scheduling and duplicate-content detection.

2. Repository Structure

U19972_AOS_Assignment1/
├── task1_process_manager/
│   ├── process_manager.sh
│   └── test_logs/
│       └── test.log
│
├── task2_job_scheduler/
│   ├── job_scheduler.py
│   ├── job_queue.txt
│   └── completed_jobs.txt
│
├── task3_submission_system/
│   ├── submission.sh
│   ├── validator.py
│   ├── hash_database.txt
│   └── submissions/
│
├── logs/
│   ├── system_monitor_log.txt
│   ├── scheduler_log.txt
│   └── submission_log.txt
│
├── Archivelogs/
│   └── *.log.gz
│
├── test_assignment1.pdf
└── README.md

Note: The folder names in this README match the structure of the submitted project.

3. Prerequisites

The project is intended to run on Linux or another Unix-like environment with Bash and Python 3.

Required software

Linux / Unix-like operating system

Bash

Python 3

gzip

find

du

df

free

ps

top

vmstat

stat

bc

Check installed versions

bash --version
python3 --version

If required, install missing standard utilities using your operating system's package manager.

4. Make Scripts Executable

From the project root directory, run:

chmod +x task1_process_manager/process_manager.sh
chmod +x task2_job_scheduler/job_scheduler.py
chmod +x task3_submission_system/submission.sh
chmod +x task3_submission_system/validator.py

Task 1 – Process Manager

5. Purpose

The Process Manager is a Bash-based Data Centre system designed to monitor system resources, inspect running processes, check disk usage, and archive large log files.

6. How to Run

From the project root:

cd task1_process_manager
bash process_manager.sh

Alternatively, after making the script executable:

./process_manager.sh

7. Menu Options

1. Monitor System Resources

Displays:

CPU information using top

Memory usage using free -h

Virtual memory statistics using vmstat

The activity is recorded in:

logs/system_monitor_log.txt

2. Process Management

Displays the top 10 memory-consuming processes.

The user can enter a PID to terminate a process. The system:

Checks whether the PID exists.

Requires confirmation before termination.

Uses SIGTERM for normal process termination.

Blocks termination of configured critical system processes.

Records the action in the audit log.

3. Disk Usage Inspection

The user enters a directory path.

The system displays:

Overall filesystem usage using df -h

Directory size using du -sh

The largest subdirectories using du

Invalid or non-existing directories are rejected safely.

4. Log File Detection & Archiving

The user enters a directory to scan.

The system searches recursively for:

*.log

files larger than 50 MB.

Selected oversized log files are compressed into the project's Archivelogs/ directory as .gz archives. The original log file is removed after successful compression.

The system also checks the archive directory size and warns when it exceeds 1 GB.

5. Exit

The system asks for confirmation:

Are you sure you want to exit? (Y/N)

Only Y or y confirms the exit.

Task 2 – HPC Job Scheduler

8. Purpose

The HPC Job Scheduler is a Python-based command-line application for managing jobs submitted to a simulated High Performance Computing environment.

9. How to Run

From the project root:

cd task2_job_scheduler
python3 job_scheduler.py

If executable:

./job_scheduler.py

10. Job Queue Format

Pending jobs are stored in:

task2_job_scheduler/job_queue.txt

Each job uses the following format:

StudentID | JobName | ExecutionTime | Priority

Example:

IT2024 | DataAnalysis | 20 | 8

Where:

StudentID identifies the student.

JobName identifies the job.

ExecutionTime is the estimated execution time in seconds.

Priority is a value from 1 to 10.

Priority 10 is the highest priority.

11. Menu Options

1. View Pending Jobs

Displays all jobs currently stored in job_queue.txt.

2. Submit Job

Prompts the user to enter:

Student ID

Job name

Execution time

Priority

Validation ensures:

Student ID is not empty.

Job name is not empty.

Execution time is a positive integer.

Priority is between 1 and 10.

3. Run Scheduler

Provides two scheduling algorithms:

Round Robin

Uses a 5-second time quantum.

Each job receives up to 5 seconds of processing.

Jobs with remaining execution time are re-queued.

The process continues until all jobs are completed.

Priority Scheduling

Jobs are sorted by priority.

Priority 10 is treated as the highest.

Jobs are processed in descending priority order.

Each job is completed in full before the next job is selected.

After scheduling, pending jobs are removed from job_queue.txt and completed jobs are recorded in:

completed_jobs.txt

4. View Completed Jobs

Displays the jobs recorded in:

task2_job_scheduler/completed_jobs.txt

5. Exit

The system asks for Y/N confirmation before exiting.

Task 3 – Secure Submission System

12. Purpose

The Secure Submission System is a Bash-based application that provides controlled assignment submission and basic security features.

13. How to Run

From the project root:

cd task3_submission_system
bash submission.sh

Alternatively:

./submission.sh

14. Menu Options

1. Submit Assignment

The user provides:

Student ID

Full path to the assignment file

The system validates:

File format

Only these formats are accepted:

.pdf
.docx

File size

The maximum allowed size is:

5 MB

Duplicate content

The system calculates a SHA-256 hash and compares it with:

hash_database.txt

If the same hash already exists, the submission is rejected as a duplicate.

Accepted files are copied to:

task3_submission_system/submissions/

The stored filename follows this pattern:

StudentID_originalfilename

2. Check if File Already Submitted

The user selects a file and the system calculates its SHA-256 hash.

The result is either:

DUPLICATE

or:

NEW

3. List Submitted Files

Displays the files currently stored in:

task3_submission_system/submissions/

The file size and total number of submitted files are also displayed.

4. Simulate Login Attempt

The login simulation demonstrates:

Successful login

Failed login attempts

Account locking

Suspicious activity detection

For the demonstration, the correct password is the same as the Student ID.

Example:

Student ID: IT2024
Password:   IT2024

An account is locked after 3 consecutive failed attempts.

Multiple failed attempts within a 60-second window are flagged as suspicious activity.

The login state is maintained during the running session of the Bash program; restarting the program resets the in-memory login state.

5. Exit

The system requires Y/N confirmation before exiting.

15. SHA-256 Duplicate Detection

The duplicate detector is implemented in:

task3_submission_system/validator.py

The validator supports two commands.

Check a file

python3 validator.py check_hash <file_path> <hash_database>

Example:

python3 validator.py check_hash ../test_assignment1.pdf hash_database.txt

Possible results:

DUPLICATE

or:

NEW

Register a file hash

python3 validator.py register_hash <file_path> <hash_database>

The database stores the hash, filename, and registration timestamp.

Example database record:

SHA256_HASH | filename.pdf | 2026-08-13 14:30:00

16. Logging and Audit Trail

Each task maintains a separate audit log.

Task

Log File

Task 1 – Process Manager

logs/system_monitor_log.txt

Task 2 – HPC Scheduler

logs/scheduler_log.txt

Task 3 – Submission System

logs/submission_log.txt

Logs include timestamps and information about important system activities such as:

System startup

Menu actions

Resource monitoring

Process management

Disk inspections

Log archiving

Job submission

Scheduling events

Job completion

File validation

Duplicate detection

Login attempts

Account lockouts

System exit

17. Security Features

The project demonstrates several basic security controls.

Security Control

Implementation

File format validation

Only .pdf and .docx are accepted

File size validation

Maximum 5 MB

Duplicate detection

SHA-256 hash comparison

Account lockout

3 consecutive failed login attempts

Suspicious activity detection

Multiple attempts within 60 seconds

Critical process protection

Configured critical processes cannot be terminated

User confirmation

Confirmation before process termination and exit

Audit logging

Timestamped events stored in log files

18. Scheduling Algorithms

Algorithm

Behaviour

Round Robin

Each job receives a 5-second quantum; unfinished jobs are re-queued

Priority Scheduling

Jobs are sorted by priority, with 10 as the highest priority

Example

Given:

IT2024 | JobA | 12 | 5
IT2025 | JobB | 8  | 9
IT2026 | JobC | 4  | 7

Priority Scheduling executes:

JobB → JobC → JobA

because the priorities are:

9 → 7 → 5

Round Robin instead cycles through the jobs using the 5-second quantum until all jobs finish.

19. Testing

The project can be tested by running each system independently.

Task 1

Test:

Resource monitoring

Valid and invalid directory paths

Process listing

Safe process termination

Critical process protection

Detection of .log files larger than 50 MB

Log compression

Task 2

Test:

Adding valid jobs

Rejecting invalid execution times

Rejecting priorities outside 1–10

Viewing pending jobs

Round Robin scheduling

Priority scheduling

Viewing completed jobs

Task 3

Test:

Valid PDF submission

Valid DOCX submission

Invalid file extension

File larger than 5 MB

Duplicate file submission

New file hash registration

Listing submitted files

Successful login

Failed login attempts

Account lock after 3 failures

Suspicious activity within 60 seconds

20. Important Notes

Run the scripts from their respective task directories as shown above.

Ensure the required commands are available in the operating system.

The project is designed for a Unix/Linux command-line environment.

Do not use real production credentials or sensitive data during demonstrations.

The login system is a simulation for assignment purposes and is not intended as a production authentication system.

The scheduler simulates job execution and records scheduling events; it does not launch real HPC processes.

21. Quick Start

From the project root:

chmod +x task1_process_manager/process_manager.sh
chmod +x task2_job_scheduler/job_scheduler.py
chmod +x task3_submission_system/submission.sh
chmod +x task3_submission_system/validator.py

Run Task 1:

cd task1_process_manager
./process_manager.sh

Run Task 2:

cd ../task2_job_scheduler
python3 job_scheduler.py

Run Task 3:

cd ../task3_submission_system
./submission.sh

22. Conclusion

This assignment demonstrates practical operating-system and system-administration concepts through three integrated command-line applications. The project covers Linux process and resource management, disk and log management, CPU scheduling algorithms, file validation, SHA-256 duplicate detection, basic access-control simulation, and audit logging.

Together, these components provide a practical demonstration of how Bash scripting and Python can be used to automate and secure common tasks within a University Data Centre environment.
