[![Alire indexed](https://img.shields.io/endpoint?url=https://alire.ada.dev/badges/workers.json)](https://alire.ada.dev/crates/workers)

# workers

Straightforward worker pools for Ada. Includes a bonus RAII critical section.

Usage example:

```Ada
declare
   type Job_Data is ...
   procedure Process (Job : Job_Data) is ...

   package Parallel_Jobs is
     new Workers.Once (Job_Data, Process);
   --  Defaults to as many worker tasks as CPU cores

   Pool : Parallel_Jobs.Pool;
begin
   for Job of Jobs loop
      Pool.Add (Job); -- Starts execution
   end loop;

   Pool.No_More_Jobs;
   --  Blocks until all jobs are completed
end;
```

Generic formal parameters:

```Ada
generic
   type Input (<>) is private;
   --  The type describing the job to perform

   with procedure Process (Job : Input);
   --  This procedure will be called by worker threads

   Size : Positive := Positive (System.Multiprocessors.Number_Of_CPUs);
   --  How many workers will the pool have

   Early_Abort : Boolean := True;
   --  If any job raises, stop all others ASAP; otherwise complete them all.
package Workers.Once with Preelaborate is ...
```
