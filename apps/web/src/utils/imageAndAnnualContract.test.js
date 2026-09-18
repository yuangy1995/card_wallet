// @vitest-environment node
import {describe,it,expect,vi} from 'vitest'
import images from '../../../../contracts/card-wallet/fixtures/card-images.json'
import annual from '../../../../contracts/card-wallet/fixtures/annual-fees.json'
import {IMAGE_LIMITS,canAppendImages,validateImageInput} from './cardImageImport'
import {settingAnnualStatus} from './cardReminderRules'
describe('shared attachment and annual-fee contracts',()=>{
 it('uses the common image limits',()=>expect(IMAGE_LIMITS).toEqual(images.limits))
 for (const c of images.appendCases) it(`image count ${c.existing}+${c.incoming}`,()=>expect(canAppendImages(c.existing,c.incoming)).toBe(c.expected))
 for (const c of annual) it(c.id,()=>{
   const source={...c, id:c.id, cardImages:[{id:'existing',data:'preserved',futureField:42}]}
   const result=settingAnnualStatus(source,'1',new Date(c.now))
   expect(result.nextAnnualFeeCollectionTime).toBe(c.expectedDate);expect(result.isQualified).toBe(c.expectedStatus)
   expect(result.cardImages).toBe(source.cardImages);expect(source.isQualified).toBe(c.isQualified)
 })
 it('rejects bad MIME, empty and oversized new inputs',()=>{
   for (const f of [{type:'image/svg+xml',size:1},{type:'image/jpeg',size:0},{type:'image/png',size:10485761}]) expect(()=>validateImageInput(f)).toThrow()
   expect(()=>validateImageInput({type:'image/jpeg',size:10485760})).not.toThrow()
 })
})
