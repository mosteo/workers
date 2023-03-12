private with Ada.Containers.Indefinite_Doubly_Linked_Lists;
private with Ada.Exceptions;
private with Ada.Finalization;
with System.Multiprocessors;

--  One-shot pool; it is used by adding seed Inputs and then releasing the
--  kraken^H^H pool. Once finished the tasks go away.

generic
   type Input (<>) is private;
   --  The type describing the job to perform

   with procedure Process (Job : Input);
   --  This procedure will be called by worker threads, must generate
   --  results and do something with them (taking care of thread safety,
   --  see Worker.Mutexes for a simple mutex or use your own protected type).

   Size : Positive := Positive (System.Multiprocessors.Number_Of_CPUs);
   --  How many workers will the pool have

   Early_Abort : Boolean := True;
   --  If any job raises, stop all others ASAP. Otherwise complete them all.
   --  See comment on No_More_Jobs.

package Workers.Once is

   type Pool is tagged limited private;

   procedure Add (This : in out Pool; Job : Input);
   --  Add a job; workers will start processing it ASAP. This call is
   --  task-safe, so jobs can be added from multiple threads, even from inside
   --  a Process call. After No_More_Jobs has been called, calling Add will
   --  raise Program_Error.

   procedure No_More_Jobs (This : in out Pool);
   --  Notify no more jobs will be added, so tasks can die once everything is
   --  processed. Will wait for all jobs to complete. Will raise a copy of the
   --  first exception caught during job execution, if any.

   function Load (This : Pool) return Rate;
   --  Rate of busy workers

   function Accepting (This : Pool) return Boolean;
   --  Says if No_More_Jobs has been already called. Informative only as it's
   --  not race-conditions-safe.

   function Completion (This : Pool) return Rate;
   --  #Completed / #Added

private

   use Ada.Exceptions;

   type Pool_Access is access all Pool;

   task type Activator (Parent : Pool_Access);

   task type Worker is
      entry Set_Parent (Parent : Pool_Access);
   end Worker;

   type Worker_Array is array (1 .. Size) of Worker;

   package Input_Lists is
     new Ada.Containers.Indefinite_Doubly_Linked_Lists (Input);

   Die_Now : exception;

   protected type Store is
      procedure Add (Job : Input);
      entry Get (Job : out Input_Lists.List);
      --  Will block if no more. Returns a list containing a single job. Will
      --  raise Die_Now once no more jobs an no more incoming.
      procedure Ready;
      --  Mark the worker is free

      function Load return Rate;
      --  Busy / Size

      function Completion return Rate;

      function Is_Done return Boolean;

      procedure No_More_Jobs;
      --  Mark no more jobs expected

      procedure Checkout; -- Each task checks out once
      entry Wait_For_All; -- Block until all workers done

      procedure Store_Error (E : Exception_Occurrence);
   private
      Ended : Natural := 0;
      Busy  : Natural := 0;

      Done : Boolean := False;
      Jobs : Input_Lists.List;
      Jobs_Created : Natural := 0;

      Error : Exception_Occurrence;
   end Store;

   type Pool is tagged limited record
      Started : Boolean := False;
      Jobs    : Store;
      Workers : Worker_Array;
      Awaker  : Activator (Pool'Unchecked_Access);
   end record;

   procedure Set_Parents (This : in out Pool);

   ----------------
   -- Completion --
   ----------------

   function Completion (This : Pool) return Rate
   is (This.Jobs.Completion);

   ----------
   -- Done --
   ----------

   function Accepting (This : Pool) return Boolean
   is (not This.Jobs.Is_Done);

   ----------
   -- Load --
   ----------

   function Load (This : Pool) return Rate
   is (This.Jobs.Load);

end Workers.Once;
