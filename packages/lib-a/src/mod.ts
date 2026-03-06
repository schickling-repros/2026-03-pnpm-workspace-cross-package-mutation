import { Effect, HashSet, Schema, Scope } from 'effect'

const User = Schema.Struct({
  name: Schema.String,
  age: Schema.Number,
})

/** Return type involves HashSet and Scope — sub-module types that trigger TS2742 */
export const makeService = Effect.gen(function* () {
  const scope = yield* Scope.make()
  const users = HashSet.empty<typeof User.Type>()
  const decode = Schema.decodeUnknown(User)
  return { scope, users, decode }
})
