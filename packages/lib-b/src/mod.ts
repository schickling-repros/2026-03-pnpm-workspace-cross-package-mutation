import { makeService } from 'lib-a'

/** Wrapping the import forces TypeScript to infer and spell out the full type
 * in lib-b's declaration file, referencing effect types from lib-a's scope */
export const service = makeService
