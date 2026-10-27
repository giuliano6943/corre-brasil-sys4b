trigger InscricaoTrigger on Inscricao__c (
    before insert, before update,
    after insert, after update, after delete, after undelete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            InscricaoTriggerHandler.aoInserirAntes(Trigger.new);
        } else if (Trigger.isUpdate) {
            InscricaoTriggerHandler.aoAtualizarAntes(Trigger.new, Trigger.oldMap);
        }
    } else {
        if (Trigger.isDelete) {
            InscricaoTriggerHandler.aoGravarDepois(Trigger.old);
        } else {
            InscricaoTriggerHandler.aoGravarDepois(Trigger.new);
        }
    }
}