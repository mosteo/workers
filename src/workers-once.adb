with Ada.Exceptions;
with GNAT.IO; use GNAT.IO;
with Workers.Mutexes;

package body Workers.Once is

   ---------
   -- Add --
   ---------

   procedure Add (This : in out Pool; Job : Input) is
   begin
      This.Jobs.Add (Job);
   end Add;

   -----------------
   -- Set_Parents --
   -----------------

   procedure Set_Parents (This : in out Pool) is
   begin
      for Worker of This.Workers loop
         Worker.Set_Parent (This'Unchecked_Access);
         --  No risks as the parent will wait for all tasks terminated to go
         --  out of scope.
      end loop;
   end Set_Parents;

   ------------------
   -- No_More_Jobs --
   ------------------

   procedure No_More_Jobs (This : in out Pool) is
   begin
      This.Jobs.No_More_Jobs;
      This.Jobs.Wait_For_All;
   end No_More_Jobs;

   -----------
   -- Store --
   -----------

   protected body Store is

      ---------
      -- Add --
      ---------

      procedure Add (Job : Input) is
      begin
         if Done then
            raise Program_Error with "Adding job after marking done";
         end if;

         Jobs.Append (Job);
         Jobs_Created := Jobs_Created + 1;
      end Add;

      ---------
      -- Get --
      ---------

      entry Get (Job : out Input_Lists.List)
        when not Jobs.Is_Empty or else Done
      is
      begin
         Busy := Busy + 1;

         if Done and then Jobs.Is_Empty then
            raise Die_Now;
         elsif Early_Abort and then Exception_Identity (Error) /= Null_Id then
            raise Die_Now;
         end if;

         Job.Clear;
         Job.Append (Jobs.First_Element);
         Jobs.Delete_First;
      end Get;

      -----------
      -- Ready --
      -----------

      procedure Ready is
      begin
         Busy := Busy - 1;
      end Ready;

      ----------------
      -- Completion --
      ----------------

      function Completion return Rate
      is (Rate ((Float (Jobs_Created) - Float (Jobs.Length)) / Float (Jobs_Created)));

      -------------
      -- Is_Done --
      -------------

      function Is_Done return Boolean is (Done);

      ----------
      -- Load --
      ----------

      function Load return Rate is (Rate (Float (Busy) / Float (Size)));

      ------------------
      -- No_More_Jobs --
      ------------------

      procedure No_More_Jobs is
      begin
         Done := True;
      end No_More_Jobs;

      --------------
      -- Checkout --
      --------------

      procedure Checkout is
      begin
         Ended := Ended + 1;
      end Checkout;

      ------------------
      -- Wait_For_All --
      ------------------

      entry Wait_For_All when Ended = Size is
      begin
         if Exception_Identity (Error) /= Null_Id then
            Reraise_Occurrence (Error);
         end if;
      end Wait_For_All;

      -----------------
      -- Store_Error --
      -----------------

      procedure Store_Error (E : Exception_Occurrence) is
      begin
         if Exception_Identity (Error) = Null_Id then
            Save_Occurrence (Error, E);
         end if;
      end Store_Error;

   end Store;

   ---------------
   -- Activator --
   ---------------

   task body Activator is
   begin
      for Worker of Parent.Workers loop
         Worker.Set_Parent (Parent);
      end loop;
   end Activator;

   ------------
   -- Worker --
   ------------

   task body Worker is
      Parent : Pool_Access;
      Job    : Input_Lists.List;
   begin
      accept Set_Parent (Parent : Pool_Access) do
         Worker.Parent := Parent;
      end;

      loop
         begin
            Parent.Jobs.Get (Job);
            Process (Job.Constant_Reference (Job.First));
            Parent.Jobs.Ready;
         exception
            when Die_Now =>
               Parent.Jobs.Ready;
               exit;
            when E : others =>
               Parent.Jobs.Ready;
               Parent.Jobs.Store_Error (E);
         end;
      end loop;

      Parent.Jobs.Checkout;
   exception
      when E : others =>
         Put_Line ("Worker: "
                   & Ada.Exceptions.Exception_Name (E) & ": "
                   & Ada.Exceptions.Exception_Message (E));
         raise;
   end Worker;

end Workers.Once;
