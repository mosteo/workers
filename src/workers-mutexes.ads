with Ada.Finalization;
with Ada.Task_Identification;

package Workers.Mutexes with Preelaborate is

   package TID renames Ada.Task_Identification;

   type Mutex (Reentrant : Boolean) is tagged private
     with Static_Predicate => Mutex.Reentrant = False;
   --  Trying to set it to True will raise Unimplemented, for now.
   --  All calls on methods of this type are potentially blocking.
   --  To use it, use the following companion type.

   type Critical_Section (On : access Mutex) is
     new Ada.Finalization.Limited_Controlled with private;
   --  Declare it in the scope where you want exclusive access, using a Mutex

private

   subtype Owner_Id is Ada.Task_Identification.Task_Id;
   use type Owner_Id;

   protected type Binary_Mutex is
      entry Seize (Taker : Owner_Id);
      procedure Yield (Giver : Owner_Id);
      function Owned_By return Owner_Id;
   private
      Owner : Owner_Id := TID.Null_Task_Id;
   end Binary_Mutex;

   type Mutex (Reentrant : Boolean) is tagged limited record
      Lock : Binary_Mutex;
   end record;

   function Owner (This : Mutex) return Owner_Id;

   procedure Seize (This : in out Mutex)
     with Post => This.Owner = TID.Current_Task;
   --  Either get it or block on it until gotten it

   procedure Yield (This : in out Mutex);
   --  You must have seized it prior

   type Critical_Section (On : access Mutex) is
     new Ada.Finalization.Limited_Controlled with null record;

   overriding procedure Initialize (This : in out Critical_Section);

   overriding procedure Finalize (This : in out Critical_Section);

end Workers.Mutexes;
