package Workers with Pure is

   Unimplemented : exception;

   type Rate is delta 0.0001 digits 5 range 0.0 .. 1.0;

end Workers;
