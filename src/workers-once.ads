private with Ada.Containers.Indefinite_Doubly_Linked_Lists;
with System.Multiprocessors;

--  One-shot pool; it is used by adding seed Inputs and then releasing the
--  kraken^H^H pool. Once finished the tasks go away.

generic
   type Input (<>) is private;
   --  The type describing the job to perform

   with procedure Process (Job : Input);
   --  This procedure will be called by worker threads, must generate results
   --  and do something with them (thread-safely).

   Size : Positive := Positive (System.Multiprocessors.Number_Of_CPUs);
   --  How many workers will the pool have
package Workers.Once is

   --  To be able to have a default we expose an internal record

   type Pool is tagged limited private;

   procedure Add (This : in out Pool; Job : Input);

   procedure Start (This : in out Pool);
   --  This call will release the workers; any use of Add after this point will
   --  result in a Program_Error.

private

   task type Worker is
      entry Start;
   end Worker;

   type Worker_Array is array (1 .. Size) of Worker;

   package Input_Lists is
     new Ada.Containers.Indefinite_Doubly_Linked_Lists (Input);

   No_More_Jobs : exception;

   protected type Store is
      procedure Add (Job : Input);
      function Get return Input; -- Will raise if no more jobs available
   end Store;

   type Pool is tagged limited record
      Started : Boolean := False;
      Jobs    : Store;
      Workers : Worker_Array;
   end record;

end Workers.Once;
