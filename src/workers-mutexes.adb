package body Workers.Mutexes is

   protected body Binary_Mutex is

      -----------
      -- Seize --
      -----------

      entry Seize (Taker : Owner_Id) when Owner = TID.Null_Task_Id is
      begin
         Owner := Taker;
      end Seize;

      -----------
      -- Yield --
      -----------

      procedure Yield (Giver : Owner_Id) is
      begin
         if Giver = Owner then
            Owner := TID.Null_Task_Id;
         else
            raise Program_Error with "Attempt to yield a non-owned mutex";
         end if;
      end Yield;

      --------------
      -- Owned_By --
      --------------

      function Owned_By return Owner_Id is (Owner);

   end Binary_Mutex;

   ----------------
   -- Initialize --
   ----------------

   overriding procedure Initialize (This : in out Critical_Section) is
   begin
      This.On.Seize;
   end Initialize;

   --------------
   -- Finalize --
   --------------

   overriding procedure Finalize (This : in out Critical_Section) is
   begin
      This.On.Yield;
   end Finalize;

   function Owner (This : Mutex) return Owner_Id
   is (This.Lock.Owned_By);

   -----------
   -- Seize --
   -----------

   procedure Seize (This : in out Mutex) is
   begin
      This.Lock.Seize (TID.Current_Task);
   end Seize;

   procedure Yield (This : in out Mutex) is
   begin
      This.Lock.Yield (TID.Current_Task);
   end Yield;

end Workers.Mutexes;
