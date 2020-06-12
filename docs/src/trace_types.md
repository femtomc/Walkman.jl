One unique aspect enabled by the "compiler plugin" philosophy is the ability to utilize static analysis to identify when dependence and control flow information can be utilized to construct highly efficient trace types. This idea is found in a highly effective form in Gen. Because Gen currently operates at the syntactical level, Gen (mostly) requires that the user provide call context specific information about changing arguments, as well as dependence annotations (e.g. `(static)`) to generative functions. This helps Gen identify when things need to be updated, when things do not need to be updated, and what things can be cached. When call incremental inference routines, these elements are incredibly important to maximize performance.

Jaynes also provides a set of interfaces to enable the user to tell Jaynes how to do things more effectively. However, Jaynes also includes a set of automatic passes which can be used to recursively derive information about a call site without user-provided annotations. These passes work using a hybrid tracing approach provided by [Mjolnir.jl](https://github.com/MikeInnes/Mjolnir.jl) and can be used without knowledge of runtime values (but do require type information to work effectively). If the analysis fails, the fallback is the normal, unoptimized `HierarchicalTrace` type. These passes are called automatically before any inference routine (but can be turned off if the user so desires).

Here, we'll discuss the details (and limitations) of this pass.